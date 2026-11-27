import 'dart:async';

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/hosts/hosts_page.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import 'fakes.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets(
      'pair confirmation and save keep input private at ${size.width}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final adapter = FakePairing();
        final repo = MemoryProfiles();
        final graph = createAppDependencies(
          initialLink: Uri(path: '/pair'),
          profileRepository: repo,
          endpointProber: FakeProber(),
          endpointPairing: adapter,
          qrInput: FakeQrInput(),
        );
        await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('pairing-link')),
          'fake-test-link',
        );
        await tester.pumpAndSettle();
        expect(adapter.calls, 0);
        expect(find.text('http://127.0.0.1:4096/'), findsOneWidget);
        expect(find.text('fake-test-code'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('confirm-pairing')));
        await tester.pumpAndSettle();
        expect(adapter.calls, 1);
        await tester.tap(find.byKey(const ValueKey('save-pairing')));
        await tester.pumpAndSettle();
        expect(repo.profiles, hasLength(1));
        expect(repo.profiles.single.harnessKind, 'opencode');
        // Saving returns to the server list instead of an emptied form.
        expect(find.byType(HostsPage), findsOneWidget);
        expect(find.byKey(const ValueKey('pairing-link')), findsNothing);
        expect(find.text('fake-test-paired'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('a pairing link arriving in Manual shows the link mode again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final graph = createAppDependencies(
      initialLink: Uri(path: '/pair'),
      profileRepository: MemoryProfiles(),
      endpointProber: FakeProber(),
      endpointPairing: FakePairing(),
      qrInput: FakeQrInput(),
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-method-manual')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('endpoint-url')), findsOneWidget);
    // The native link handler's order: empty, prepare, input, go.
    graph.pairing!.empty();
    // A link without a query: the fake adapter only knows its own codes.
    final route = graph.navigation.prepareLink(Uri(path: '/pair'));
    graph.pairing!.input('fake-test-link');
    graph.router.go(route);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('endpoint-url')), findsNothing);
    expect(find.byKey(const ValueKey('pairing-link')), findsOneWidget);
    expect(find.text('http://127.0.0.1:4096/'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a link during a manual check drops it without saving', (
    tester,
  ) async {
    final repo = MemoryProfiles();
    final reply = Completer<EndpointAssessment>();
    final graph = createAppDependencies(
      initialLink: Uri(path: '/pair'),
      profileRepository: repo,
      endpointProber: FakeProber()..pendingResult = reply.future,
      endpointPairing: FakePairing(),
      qrInput: FakeQrInput(),
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-method-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('endpoint-url')),
      'http://127.0.0.1:4096/',
    );
    await tester.enterText(
      find.byKey(const ValueKey('endpoint-secret')),
      'fake-test-secret',
    );
    await tester.tap(find.byKey(const ValueKey('save-endpoint')));
    await tester.pump();
    graph.pairing!.empty();
    final route = graph.navigation.prepareLink(Uri(path: '/pair'));
    graph.pairing!.input('fake-test-link');
    graph.router.go(route);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('pairing-link')), findsOneWidget);
    // The dropped check's late answer neither saves nor leaves the screen.
    reply.complete(const EndpointAssessment(EndpointStatus.compatible));
    await tester.pumpAndSettle();
    expect(repo.profiles, isEmpty);
    expect(find.byKey(const ValueKey('pairing-link')), findsOneWidget);
    expect(find.byType(HostsPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a pairing name with control characters is refused', (
    tester,
  ) async {
    final repo = MemoryProfiles();
    final graph = createAppDependencies(
      initialLink: Uri(path: '/pair'),
      profileRepository: repo,
      endpointProber: FakeProber(),
      endpointPairing: FakePairing(),
      qrInput: FakeQrInput(),
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pairing-link')),
      'fake-test-link',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-pairing')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pairing-label')),
      'bad\u0007name',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-pairing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-pairing')));
    await tester.pumpAndSettle();
    expect(repo.profiles, isEmpty);
    expect(
      find.text('Enter a valid server name (1–160 characters).'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a link arriving before the rebuild still drops the check', (
    tester,
  ) async {
    final repo = MemoryProfiles();
    final reply = Completer<EndpointAssessment>();
    final graph = createAppDependencies(
      initialLink: Uri(path: '/pair'),
      profileRepository: repo,
      endpointProber: FakeProber()..pendingResult = reply.future,
      endpointPairing: FakePairing(),
      qrInput: FakeQrInput(),
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-method-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('endpoint-url')),
      'http://127.0.0.1:4096/',
    );
    await tester.enterText(
      find.byKey(const ValueKey('endpoint-secret')),
      'fake-test-secret',
    );
    await tester.tap(find.byKey(const ValueKey('save-endpoint')));
    await tester.pump();
    graph.pairing!.empty();
    final route = graph.navigation.prepareLink(Uri(path: '/pair'));
    graph.pairing!.input('fake-test-link');
    graph.router.go(route);
    // The answer lands before any frame rebuilds the screen with the link.
    reply.complete(const EndpointAssessment(EndpointStatus.compatible));
    await tester.pumpAndSettle();
    expect(repo.profiles, isEmpty);
    expect(find.byKey(const ValueKey('pairing-link')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a wide dialog opened by a link closes to the server list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final graph = createAppDependencies(
      initialLink: Uri(path: '/pair'),
      profileRepository: MemoryProfiles(),
      endpointProber: FakeProber(),
      endpointPairing: FakePairing(),
      qrInput: FakeQrInput(),
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pairing-link')), findsOneWidget);
    await tester.tapAt(const Offset(16, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pairing-link')), findsNothing);
    expect(find.byType(HostsPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a save tapped after a link but before the rebuild is ignored', (
    tester,
  ) async {
    final repo = MemoryProfiles();
    final graph = createAppDependencies(
      initialLink: Uri(path: '/pair'),
      profileRepository: repo,
      endpointProber: FakeProber(),
      endpointPairing: FakePairing(),
      qrInput: FakeQrInput(),
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-method-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('endpoint-url')),
      'http://127.0.0.1:4096/',
    );
    await tester.enterText(
      find.byKey(const ValueKey('endpoint-secret')),
      'fake-test-secret',
    );
    await tester.pump();
    graph.pairing!.empty();
    final route = graph.navigation.prepareLink(Uri(path: '/pair'));
    graph.pairing!.input('fake-test-link');
    graph.router.go(route);
    // The old form is still on screen; Save there must not save it.
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('save-endpoint')),
    );
    save.onPressed!();
    await tester.pumpAndSettle();
    expect(repo.profiles, isEmpty);
    expect(find.byKey(const ValueKey('pairing-link')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
