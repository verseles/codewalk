import 'dart:async';

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/hosts/hosts_page.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _TrackingProber extends FakeProber {
  final endpoints = <Uri>[];
  @override
  EndpointProbeTask start(Uri endpoint, String secret) {
    endpoints.add(endpoint);
    return super.start(endpoint, secret);
  }
}

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('add-endpoint')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('endpoint-url')),
    'http://127.0.0.1:4096/proxy/',
  );
  await tester.enterText(
    find.byKey(const ValueKey('endpoint-secret')),
    'fake-test-secret',
  );
}

void main() {
  testWidgets(
    'password repair locks identity and all probes use the original endpoint',
    (tester) async {
      final profile = EndpointProfile(
        id: 'endpoint_one',
        label: 'Original',
        endpoint: Uri.parse('http://127.0.0.1:4096/'),
      );
      final repo = MemoryProfiles()
        ..profiles.add(profile)
        ..secrets[profile.id] = 'fake-old';
      final prober = _TrackingProber();
      final graph = createAppDependencies(
        initialLink: Uri(path: '/hosts'),
        profileRepository: repo,
        endpointProber: prober,
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Password'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('endpoint-url')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('endpoint-label')))
            .enabled,
        isFalse,
      );
      await tester.enterText(
        find.byKey(const ValueKey('endpoint-secret')),
        'fake-new',
      );
      await tester.tap(find.byKey(const ValueKey('probe-endpoint')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-endpoint')));
      await tester.pumpAndSettle();
      expect(prober.endpoints, [profile.endpoint, profile.endpoint]);
      expect(repo.profiles.single, same(profile));
      expect(repo.profiles.single.label, 'Original');
      expect(await repo.readSecret(profile), 'fake-new');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('hosts form remains usable in RTL with enlarged text on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: MemoryProfiles(),
      endpointProber: FakeProber(),
    );
    graph.preferences.setLocale(const Locale('ar'));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: CodeWalkV2Bootstrap(dependencies: graph),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(HostsPage))),
      TextDirection.rtl,
    );
    expect(
      MediaQuery.textScalerOf(tester.element(find.byType(HostsPage))).scale(10),
      20,
    );
    await tester.tap(find.byKey(const ValueKey('add-endpoint')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('endpoint-url')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets(
      'persistent authored profile and untested chip at ${size.width}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = MemoryProfiles();
        final probe = FakeProber()
          ..assessment = const EndpointAssessment(
            EndpointStatus.untested,
            version: '2.0.23',
          );
        final graph = createAppDependencies(
          initialLink: Uri(path: '/hosts'),
          profileRepository: repo,
          endpointProber: probe,
        );
        await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
        await tester.pumpAndSettle();
        await openForm(tester);
        await tester.tap(find.byKey(const ValueKey('probe-endpoint')));
        await tester.pumpAndSettle();
        expect(find.text('Untested version · 2.0.23'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-endpoint')));
        await tester.pumpAndSettle();
        expect(repo.profiles.single.endpoint.port, 4096);
        expect(find.text('http://127.0.0.1:4096/proxy/'), findsOneWidget);
        expect(find.text('fake-test-secret'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'legacy detection opens a full-screen explainer with two bounded actions',
    (tester) async {
      final probe = FakeProber()
        ..assessment = const EndpointAssessment(
          EndpointStatus.legacyServer,
          version: '1.2.3',
        );
      final graph = createAppDependencies(
        initialLink: Uri(path: '/hosts'),
        profileRepository: MemoryProfiles(),
        endpointProber: probe,
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
      await tester.pumpAndSettle();
      await openForm(tester);
      await tester.tap(find.byKey(const ValueKey('probe-endpoint')));
      await tester.pumpAndSettle();
      expect(find.byType(LegacyEndpointPage), findsOneWidget);
      expect(
        find.text('This server runs OpenCode 1. CodeWalk 2 needs OpenCode 2.'),
        findsOneWidget,
      );
      expect(find.text('Download CodeWalk 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('legacy-download')));
      await tester.pumpAndSettle();
      expect(find.text(legacyDownloadUrl), findsOneWidget);
      await tester.tap(find.text('Server upgrade required'));
      await tester.pumpAndSettle();
      expect(find.textContaining('opencode upgrade'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('save-endpoint')),
      );
      expect(save.onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'wrong credentials block save and a failed save remains visible',
    (tester) async {
      final repo = MemoryProfiles()..failSave = true;
      final probe = FakeProber()
        ..assessment = const EndpointAssessment(
          EndpointStatus.authenticationRequired,
        );
      final graph = createAppDependencies(
        initialLink: Uri(path: '/hosts'),
        profileRepository: repo,
        endpointProber: probe,
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
      await tester.pumpAndSettle();
      await openForm(tester);
      await tester.tap(find.byKey(const ValueKey('probe-endpoint')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-endpoint')))
            .onPressed,
        isNull,
      );
      probe.assessment = const EndpointAssessment(
        EndpointStatus.compatible,
        version: '2.0.22',
      );
      await tester.tap(find.byKey(const ValueKey('probe-endpoint')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-endpoint')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('endpoint-secret')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Could not load or save profiles'),
        ),
        findsOneWidget,
      );
      expect(repo.profiles, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'catalog failure shows retry instead of claiming no saved servers',
    (tester) async {
      final repo = MemoryProfiles()..failLoad = true;
      final graph = createAppDependencies(
        initialLink: Uri(path: '/hosts'),
        profileRepository: repo,
        endpointProber: FakeProber(),
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not load or save profiles'),
        findsOneWidget,
      );
      expect(find.text('No servers found'), findsNothing);
      repo.failLoad = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No servers found'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('durable save closes the form when catalog refresh needs retry', (
    tester,
  ) async {
    final repo = MemoryProfiles();
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: repo,
      endpointProber: FakeProber(),
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await openForm(tester);
    await tester.tap(find.byKey(const ValueKey('probe-endpoint')));
    await tester.pumpAndSettle();
    repo.failLoad = true;
    await tester.tap(find.byKey(const ValueKey('save-endpoint')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.profiles, hasLength(1));
    expect(
      find.textContaining('Could not load or save profiles'),
      findsOneWidget,
    );
    expect(find.text('No servers found'), findsNothing);
    repo.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('http://127.0.0.1:4096/proxy/'), findsOneWidget);
    expect(repo.profiles, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'checking a saved profile displays progress and disables duplicate taps',
    (tester) async {
      final profile = EndpointProfile(
        id: 'endpoint_one',
        label: 'Server',
        endpoint: Uri.parse('http://127.0.0.1:4096/'),
      );
      final repo = MemoryProfiles()
        ..profiles.add(profile)
        ..secrets[profile.id] = 'fake-secret';
      final result = Completer<EndpointAssessment>();
      final probe = FakeProber()..pendingResult = result.future;
      final graph = createAppDependencies(
        initialLink: Uri(path: '/hosts'),
        profileRepository: repo,
        endpointProber: probe,
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check connection'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('endpoint-check-endpoint_one')),
        findsOneWidget,
      );
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Check connection'),
      );
      expect(button.onPressed, isNull);
      result.complete(
        const EndpointAssessment(EndpointStatus.compatible, version: '2.0.22'),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('endpoint-check-endpoint_one')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
