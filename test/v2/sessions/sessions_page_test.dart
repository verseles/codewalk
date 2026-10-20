import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_ownership.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_catalog_changes.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
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
          source.respond(
            [
              source.row(
                'first',
                title: '',
                directory:
                    '/a/very/long/workspace/path/that/should/ellipsize/in/the/compact/layout',
              ),
            ],
            next: 'A',
          );
          await tester.pumpAndSettle();
          expect(find.text(l10n.sessionExportUntitled), findsOneWidget);
          // The ownership label is on every row, in every locale and size.
          expect(find.text(l10n.sessionsOwnershipUnknown), findsOneWidget);
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
    const directory =
        '/a/very/long/workspace/path/that/should/ellipsize/in/the/compact/layout';
    source.respond([
      source.row('one', title: title, directory: directory),
    ]);
    await read;
    await tester.pumpAndSettle();
    // At 2x the header takes most of the compact viewport, so the row is
    // scrolled into view before it is tapped.
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(source.row('one').info.ref)),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    // The title is tapped, not the card: at 2x the card is taller than the
    // viewport and its center can sit below the visible area.
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
    // The group header is laid out at 2x, and its path is always read
    // left-to-right, so the separators do not reorder in a right-to-left
    // locale.
    final path = tester.widget<Text>(find.text(directory));
    expect(path.textDirection, TextDirection.ltr);
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
      final l10n = dependencies.localizations.current;
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
      source.respond([
        source.row('first'),
        source.row(
          'second',
          ownership: OwnershipInfo.known(
            OwnershipKind.liveShared,
            proof: OwnershipProof(
              source: 'adapterObservation',
              observedAt: DateTime.now(),
            ),
          ),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(source.row('second').info.ref)), findsOneWidget);
      expect(controller.sessions, hasLength(2));
      // The label follows the rows the server just returned.
      expect(find.text(l10n.sessionsOwnershipLiveShared), findsOneWidget);
      expect(find.text(l10n.sessionsOwnershipUnknown), findsOneWidget);
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

  testWidgets('the row shows only the ownership its adapter proved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
    await tester.pumpAndSettle();
    final l10n = dependencies.localizations.current;
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('sessions-profile')),
    );
    dropdown.onChanged!('profile_a');
    await tester.pump();
    final source = rig.sources.single;
    final observedAt = DateTime.now();
    OwnershipInfo proven(OwnershipKind kind) => OwnershipInfo.known(
      kind,
      proof: OwnershipProof(source: 'adapterObservation', observedAt: observedAt),
    );
    source.respond([
      source.row('live', title: 'Live', ownership: proven(OwnershipKind.liveShared)),
      source.row('host', title: 'Host', ownership: proven(OwnershipKind.hostOwned)),
      source.row(
        'saved',
        title: 'Saved',
        ownership: proven(OwnershipKind.savedHistory),
      ),
      source.row(
        'elsewhere',
        title: 'Elsewhere',
        ownership: proven(OwnershipKind.runningElsewhere),
      ),
      source.row('plain', title: 'Plain'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsOwnershipLiveShared), findsOneWidget);
    expect(find.text(l10n.sessionsOwnershipHostOwned), findsOneWidget);
    expect(find.text(l10n.sessionsOwnershipSavedHistory), findsOneWidget);
    expect(find.text(l10n.sessionsOwnershipRunningElsewhere), findsOneWidget);
    // The session the adapter did not prove shows the unknown label.
    expect(find.text(l10n.sessionsOwnershipUnknown), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    rig.dispose();
  });

  testWidgets('a list that is not the current answer shows unknown', (
    tester,
  ) async {
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
    SessionSummary fresh() => source.row(
      'fresh',
      title: 'Fresh',
      ownership: OwnershipInfo.known(
        OwnershipKind.liveShared,
        proof: OwnershipProof(
          source: 'adapterObservation',
          observedAt: DateTime.now(),
        ),
      ),
    );
    source.respond([fresh()]);
    await tester.pumpAndSettle();
    // The proof is fresh, so the row shows the ownership it proved.
    expect(find.text(l10n.sessionsOwnershipLiveShared), findsOneWidget);

    // A manual refresh in flight: the rows are not the endpoint's current
    // answer, so the label falls back to unknown.
    await tester.tap(find.byKey(const ValueKey('sessions-refresh')));
    await tester.pump();
    expect(find.text(l10n.sessionsOwnershipUnknown), findsOneWidget);
    expect(find.text(l10n.sessionsOwnershipLiveShared), findsNothing);
    source.respond([fresh()]);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsOwnershipLiveShared), findsOneWidget);

    // A failed re-read marks the list as behind: same fallback.
    directory.feeds.last.emit(const SessionCatalogChanged());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    source.fail(SessionCatalogFailure.connection);
    await tester.pumpAndSettle();
    expect(find.text(l10n.liveStale), findsOneWidget);
    expect(find.text(l10n.sessionsOwnershipUnknown), findsOneWidget);
    expect(find.text(l10n.sessionsOwnershipLiveShared), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    rig.dispose();
  });

  testWidgets('the label stops when its proof goes stale', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var clock = DateTime.utc(2026, 10, 20, 12);
    final rig = CatalogRig();
    await rig.save('a');
    final dependencies = createAppDependencies(
      initialLink: Uri(path: '/sessions'),
      profileRepository: rig.repository,
      endpointProber: FakeProber(),
      sessionCatalogFactory: rig.create,
      sessionLiveDirectory: LiveDirectory.new,
      sessionClock: () => clock,
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
    source.respond([
      source.row(
        'proven',
        title: 'Proven',
        ownership: OwnershipInfo.known(
          OwnershipKind.liveShared,
          proof: OwnershipProof(source: 'adapterObservation', observedAt: clock),
        ),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsOwnershipLiveShared), findsOneWidget);

    // The proof leaves its freshness window. The list wakes up at the
    // deadline, without any catalog event or user interaction, and the label
    // falls back to unknown.
    clock = clock.add(const Duration(minutes: 6));
    await tester.pump(const Duration(minutes: 6));
    expect(find.text(l10n.sessionsOwnershipUnknown), findsOneWidget);
    expect(find.text(l10n.sessionsOwnershipLiveShared), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    rig.dispose();
  });

  testWidgets('the label stops exactly when its proof goes stale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var clock = DateTime.utc(2026, 10, 20, 12);
    final rig = CatalogRig();
    await rig.save('a');
    final dependencies = createAppDependencies(
      initialLink: Uri(path: '/sessions'),
      profileRepository: rig.repository,
      endpointProber: FakeProber(),
      sessionCatalogFactory: rig.create,
      sessionLiveDirectory: LiveDirectory.new,
      sessionClock: () => clock,
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
    source.respond([
      source.row(
        'proven',
        title: 'Proven',
        ownership: OwnershipInfo.known(
          OwnershipKind.liveShared,
          proof: OwnershipProof(source: 'adapterObservation', observedAt: clock),
        ),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsOwnershipLiveShared), findsOneWidget);

    // The exact instant the proof leaves its window. The label becomes
    // unknown and the deadline timer drains: it must not re-arm itself at
    // the boundary, which would keep the list awake forever.
    clock = clock.add(
      sessionOwnershipProofMaxAge + const Duration(microseconds: 1),
    );
    await tester.pump(const Duration(minutes: 6));
    expect(find.text(l10n.sessionsOwnershipUnknown), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsOwnershipUnknown), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    rig.dispose();
  });

  testWidgets('the list groups the sessions by their project', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
    await tester.pumpAndSettle();
    final l10n = dependencies.localizations.current;
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('sessions-profile')),
    );
    dropdown.onChanged!('profile_a');
    await tester.pump();
    final source = rig.sources.single;
    source.respond([
      source.row('one', directory: '/work/alpha', title: 'One'),
      source.row('two', directory: '/work/beta', title: 'Two'),
      source.row('three', directory: '/work/alpha', title: 'Three'),
    ], next: 'A');
    await tester.pumpAndSettle();

    // One header per project, in the order the server returned the groups.
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('/work/alpha'), findsOneWidget);
    expect(find.text('/work/beta'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);
    // The sessions the server did not attribute share one marked group.
    expect(find.text(l10n.sessionsUnknownProject), findsNothing);

    // The grouping is recomputed from the loaded rows: a page that appends a
    // row to an earlier group keeps that row inside its group.
    final more = find.byKey(const ValueKey('sessions-more'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pump();
    source.respond([source.row('four', directory: '/work/alpha', title: 'Four')]);
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('Four'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    // The order is the projected order: the alpha group keeps its rows
    // together, the beta group follows it, and the row the later page added
    // stays inside the alpha group.
    double topOf(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(topOf('alpha'), lessThan(topOf('One')));
    expect(topOf('One'), lessThan(topOf('Three')));
    expect(topOf('Three'), lessThan(topOf('Four')));
    expect(topOf('Four'), lessThan(topOf('beta')));
    expect(topOf('beta'), lessThan(topOf('Two')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    rig.dispose();
  });

  testWidgets('a session moved elsewhere changes its group', (tester) async {
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
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('sessions-profile')),
    );
    dropdown.onChanged!('profile_a');
    await tester.pump();
    final source = rig.sources.single;
    source.respond([source.row('one', directory: '/work/alpha', title: 'One')]);
    await tester.pumpAndSettle();
    // The feed opens after the first read.
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('alpha'), findsOneWidget);

    // The endpoint moved the session: the re-read puts it in the new group.
    directory.feeds.last.emit(const SessionCatalogChanged());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    source.respond([source.row('one', directory: '/work/beta', title: 'One')]);
    await tester.pumpAndSettle();
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('alpha'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    rig.dispose();
  });

  testWidgets(
    'the sessions the server did not attribute keep a marked group',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
      await tester.pumpAndSettle();
      final l10n = dependencies.localizations.current;
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('sessions-profile')),
      );
      dropdown.onChanged!('profile_a');
      await tester.pump();
      final source = rig.sources.single;
      source.respond([
        source.row('one', directory: '/work/alpha', title: 'One'),
        source.row('two', title: 'Two'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text(l10n.sessionsUnknownProject), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      rig.dispose();
    },
  );
  group('nesting', () {
    Future<(CatalogSource, V2Localizations, LiveDirectory)> openList(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      Locale? locale,
      double scale = 1,
      DateTime Function()? clock,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rig = CatalogRig();
      addTearDown(rig.dispose);
      final directory = LiveDirectory();
      await rig.save('a');
      final dependencies = createAppDependencies(
        initialLink: Uri(path: '/sessions'),
        profileRepository: rig.repository,
        endpointProber: FakeProber(),
        sessionCatalogFactory: rig.create,
        sessionLiveDirectory: () => directory,
        sessionClock: clock,
      );
      if (locale != null) dependencies.preferences.setLocale(locale);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: CodeWalkV2Bootstrap(dependencies: dependencies),
        ),
      );
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('sessions-profile')),
      );
      dropdown.onChanged!('profile_a');
      await tester.pump();
      return (
        rig.sources.single,
        dependencies.localizations.current,
        directory,
      );
    }

    for (final size in [const Size(390, 844), const Size(1280, 800)]) {
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        testWidgets(
          'a child is drawn under its parent at $size/${locale.languageCode}',
          (tester) async {
            final (source, l10n, _) = await openList(
              tester,
              size: size,
              locale: locale,
            );
            source.respond([
              source.row(
                'grand',
                directory: '/work/alpha',
                title: 'Grand',
                parent: 'child',
              ),
              source.row(
                'child',
                directory: '/work/alpha',
                title: 'Child',
                parent: 'root',
              ),
              source.row('root', directory: '/work/alpha', title: 'Root'),
            ]);
            await tester.pumpAndSettle();
            double topOf(String text) => tester.getTopLeft(find.text(text)).dy;
            expect(topOf('Root'), lessThan(topOf('Child')));
            expect(topOf('Child'), lessThan(topOf('Grand')));
            final rtl = locale.languageCode == 'ar';
            double startOf(String id) {
              final card = find.byKey(ValueKey(source.row(id).info.ref));
              return rtl
                  ? -tester.getTopRight(card).dx
                  : tester.getTopLeft(card).dx;
            }

            expect(startOf('child') - startOf('root'), 16);
            expect(startOf('grand') - startOf('root'), 32);
            expect(find.text(l10n.sessionsChildSession), findsNWidgets(2));
            expect(find.text(l10n.sessionsChildParentElsewhere), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }

    testWidgets('the indent stops at its cap at 2x in a right-to-left locale', (
      tester,
    ) async {
      final (source, _, _) = await openList(
        tester,
        locale: const Locale('ar'),
        scale: 2,
      );
      final long = 'long '.padRight(400, 'x');
      source.respond([
        for (var i = 4; i >= 0; i--)
          source.row(
            'n$i',
            directory: '/work/alpha',
            title: 'n$i $long',
            parent: i == 0 ? null : 'n${i - 1}',
          ),
      ]);
      await tester.pumpAndSettle();
      // At 2x each card is taller than the viewport and the list builds
      // lazily, so each start edge is read while its card is in view.
      final start = <String, double>{};
      for (var i = 0; i <= 4; i++) {
        final card = find.byKey(ValueKey(source.row('n$i').info.ref));
        await tester.scrollUntilVisible(
          card,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        start['n$i'] = -tester.getTopRight(card).dx;
      }
      expect(start['n3']! - start['n0']!, 48);
      expect(start['n4'], start['n3']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a child whose parent is on the next page nests once loaded', (
      tester,
    ) async {
      final (source, l10n, _) = await openList(tester);
      source.respond([
        source.row('c', directory: '/work/alpha', title: 'Child', parent: 'p'),
      ], next: 'A');
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionsChildParentElsewhere), findsOneWidget);
      final card = find.byKey(ValueKey(source.row('c').info.ref));
      final before = tester.getTopLeft(card).dx;

      final more = find.byKey(const ValueKey('sessions-more'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pump();
      source.respond([
        source.row('p', directory: '/work/alpha', title: 'Parent'),
      ]);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Parent')).dy,
        lessThan(tester.getTopLeft(find.text('Child')).dy),
      );
      expect(card, findsOneWidget);
      expect(tester.getTopLeft(card).dx - before, 16);
      expect(find.text(l10n.sessionsChildSession), findsOneWidget);
      expect(find.text(l10n.sessionsChildParentElsewhere), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the live re-read nests and un-nests a child', (tester) async {
      // The automatic re-read keeps a cooldown on the session clock.
      var now = DateTime.utc(2026, 10, 20, 12);
      final (source, l10n, directory) = await openList(
        tester,
        clock: () => now,
      );
      source.respond([
        source.row('root', directory: '/work/alpha', title: 'Root'),
      ]);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('Root'));
      await tester.pumpAndSettle();
      final history = find.byKey(
        ValueKey('history-open-${source.row('root').info.ref.storageKey}'),
      );
      expect(history, findsOneWidget);

      // A subagent child was created: the quiet re-read nests it under the
      // parent, and the expanded parent stays expanded.
      directory.feeds.last.emit(const SessionCatalogChanged());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      source.respond([
        source.row(
          'child',
          directory: '/work/alpha',
          title: 'Child',
          parent: 'root',
        ),
        source.row('root', directory: '/work/alpha', title: 'Root'),
      ]);
      await tester.pumpAndSettle();
      final child = find.byKey(ValueKey(source.row('child').info.ref));
      final root = find.byKey(ValueKey(source.row('root').info.ref));
      expect(child, findsOneWidget);
      expect(tester.getTopLeft(child).dx - tester.getTopLeft(root).dx, 16);
      expect(history, findsOneWidget);
      expect(find.text(l10n.sessionsLoading), findsNothing);
      expect(find.text(l10n.sessionsPreviousResults), findsNothing);

      // The nested row keeps its own actions.
      await tester.longPress(find.text('Child'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionsActionRename), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // The parent is gone from the next answer: the child stays, once, where
      // the server put it, and says its parent is not shown.
      // The automatic re-read waits for its cooldown.
      now = now.add(const Duration(seconds: 3));
      directory.feeds.last.emit(const SessionCatalogChanged());
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      source.respond([
        source.row(
          'child',
          directory: '/work/alpha',
          title: 'Child',
          parent: 'root',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(child, findsOneWidget);
      expect(root, findsNothing);
      expect(find.text(l10n.sessionsChildParentElsewhere), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
