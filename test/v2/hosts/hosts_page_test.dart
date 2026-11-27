import 'dart:async';

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/hosts/hosts_page.dart';
import 'package:codewalk/features/pairing/pairing_page.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _TrackingProber extends FakeProber {
  final endpoints = <Uri>[];
  final secrets = <String>[];
  @override
  EndpointProbeTask start(
    Uri endpoint,
    String secret, {
    Duration? connectionTimeout,
  }) {
    endpoints.add(endpoint);
    secrets.add(secret);
    return super.start(endpoint, secret, connectionTimeout: connectionTimeout);
  }
}

Future<void> tapVisible(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
}

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('add-endpoint')));
  await tester.pumpAndSettle();
  // The add screen opens on the pairing link; the manual form is one tap.
  expect(find.byKey(const ValueKey('pairing-link')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('add-method-manual')));
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
      await tester.tap(
        find.byKey(const ValueKey('endpoint-actions-endpoint_one')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
          matching: find.text('Password'),
        ),
      );
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
      // Initial and replaced-credential health probes surround the two
      // explicit repair checks; all four retain the original endpoint.
      expect(prober.endpoints, List.filled(4, profile.endpoint));
      expect(prober.secrets, ['fake-old', 'fake-new', 'fake-new', 'fake-new']);
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
    expect(find.byKey(const ValueKey('add-harness')), findsOneWidget);
    expect(find.byKey(const ValueKey('pairing-link')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-method-manual')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('endpoint-url')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets(
      'persistent authored profile on a newer version at ${size.width}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = MemoryProfiles();
        final probe = FakeProber()
          ..assessment = const EndpointAssessment(
            EndpointStatus.compatible,
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
        // One Save checks the server and, when it answers, saves and closes.
        await tapVisible(tester, 'save-endpoint');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('endpoint-url')), findsNothing);
        expect(find.byType(HostsPage), findsOneWidget);
        expect(find.textContaining('Untested'), findsNothing);
        expect(repo.profiles.single.endpoint.port, 4096);
        expect(repo.profiles.single.harnessKind, 'opencode');
        expect(find.text('http://127.0.0.1:4096/proxy/'), findsOneWidget);
        expect(find.text('fake-test-secret'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('on compact windows the OpenCode 1 explainer covers the shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: MemoryProfiles(),
      endpointProber: FakeProber()
        ..assessment = const EndpointAssessment(EndpointStatus.legacyServer),
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await openForm(tester);
    await tapVisible(tester, 'save-endpoint');
    await tester.pumpAndSettle();
    expect(find.byType(LegacyEndpointPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-back')).hitTestable(),
      findsNothing,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('endpoint-url')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
      await tapVisible(tester, 'save-endpoint');
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
      // An OpenCode 1 server is never saved, not even on purpose.
      expect(find.byKey(const ValueKey('save-endpoint-anyway')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'wrong credentials offer save anyway and a failed save remains visible',
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
      await tapVisible(tester, 'save-endpoint');
      await tester.pumpAndSettle();
      expect(repo.profiles, isEmpty);
      expect(
        find.text(
          'The server is saved as Offline and checked again automatically.',
        ),
        findsOneWidget,
      );
      await tapVisible(tester, 'save-endpoint-anyway');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('endpoint-secret')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PairingPage),
          matching: find.textContaining('Could not load or save profiles'),
        ),
        findsOneWidget,
      );
      expect(repo.profiles, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('save anyway keeps an unreachable server listed as Offline', (
    tester,
  ) async {
    final repo = MemoryProfiles();
    final probe = FakeProber()
      ..assessment = const EndpointAssessment(EndpointStatus.unreachable);
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: repo,
      endpointProber: probe,
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await openForm(tester);
    await tapVisible(tester, 'save-endpoint');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not reach the server. Check the URL, TLS and VPN connection.',
      ),
      findsOneWidget,
    );
    // Editing the password withdraws the offer made for the checked input.
    await tester.enterText(
      find.byKey(const ValueKey('endpoint-secret')),
      'fake-other',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-endpoint-anyway')), findsNothing);
    await tapVisible(tester, 'save-endpoint');
    await tester.pumpAndSettle();
    await tapVisible(tester, 'save-endpoint-anyway');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('endpoint-url')), findsNothing);
    expect(repo.profiles, hasLength(1));
    expect(repo.secrets.values.single, 'fake-other');
    expect(find.text('Offline'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the harness picker offers OpenCode and lists Codex as coming soon',
    (tester) async {
      final graph = createAppDependencies(
        initialLink: Uri(path: '/hosts'),
        profileRepository: MemoryProfiles(),
        endpointProber: FakeProber(),
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-endpoint')));
      await tester.pumpAndSettle();
      final picker = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(picker.value, 'opencode');
      expect(
        [for (final item in picker.items!) (item.value, item.enabled)],
        [('opencode', true), ('codex', false)],
      );
      expect(find.text('OpenCode'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add-harness')));
      await tester.pumpAndSettle();
      expect(find.text('Codex · Coming soon'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a save in flight cannot be cancelled and then closes', (
    tester,
  ) async {
    final repo = MemoryProfiles();
    final reply = Completer<EndpointAssessment>();
    final probe = FakeProber()..pendingResult = reply.future;
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: repo,
      endpointProber: probe,
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await openForm(tester);
    await tapVisible(tester, 'save-endpoint');
    await tester.pump();
    // System Back is held while the check runs.
    await tester.binding.handlePopRoute();
    // The check's progress animates, so settle by time instead.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PairingPage), findsOneWidget);
    reply.complete(const EndpointAssessment(EndpointStatus.compatible));
    await tester.pumpAndSettle();
    expect(find.byType(PairingPage), findsNothing);
    expect(find.byType(HostsPage), findsOneWidget);
    expect(repo.profiles, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing the add screen keeps a saved server check running', (
    tester,
  ) async {
    final profile = EndpointProfile(
      id: 'endpoint_one',
      label: 'Server',
      endpoint: Uri.parse('http://127.0.0.1:4096/'),
    );
    final repo = MemoryProfiles()
      ..profiles.add(profile)
      ..secrets[profile.id] = 'fake-secret';
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: repo,
      endpointProber: FakeProber(),
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    final pending = Completer<EndpointAssessment>();
    // Hold the next manual check open.
    (graph.hosts.prober as FakeProber).pendingResult = pending.future;
    await tester.tap(
      find.byKey(const ValueKey('endpoint-actions-endpoint_one')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check connection').last);
    await tester.pump();
    expect(graph.hosts.isChecking(profile), isTrue);
    await tester.tap(find.byKey(const ValueKey('add-endpoint')));
    // The progress bar animates, so settle by time instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PairingPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PairingPage), findsNothing);
    expect(graph.hosts.isChecking(profile), isTrue);
    pending.complete(const EndpointAssessment(EndpointStatus.compatible));
    await tester.pumpAndSettle();
    expect(graph.hosts.isChecking(profile), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a deferred retry stays fenced after a failed save anyway', (
    tester,
  ) async {
    final repo = MemoryProfiles()..failSave = true;
    final probe = FakeProber()
      ..assessment = EndpointAssessment(
        EndpointStatus.serviceUnavailable,
        retryAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: repo,
      endpointProber: probe,
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await openForm(tester);
    await tapVisible(tester, 'save-endpoint');
    await tester.pumpAndSettle();
    await tapVisible(tester, 'save-endpoint-anyway');
    await tester.pumpAndSettle();
    expect(repo.profiles, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-endpoint')))
          .onPressed,
      isNull,
    );
    // The reason Save stays held remains on screen after the failed save.
    expect(find.text('not available'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a server deferring checks indefinitely can still be saved', (
    tester,
  ) async {
    final repo = MemoryProfiles();
    final probe = FakeProber()
      ..assessment = const EndpointAssessment(
        EndpointStatus.serviceUnavailable,
        retryDeferred: true,
      );
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: repo,
      endpointProber: probe,
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await openForm(tester);
    await tapVisible(tester, 'save-endpoint');
    await tester.pumpAndSettle();
    // It is not checked again automatically, so nothing promises that.
    expect(
      find.text(
        'The server is saved as Offline and checked again automatically.',
      ),
      findsNothing,
    );
    await tapVisible(tester, 'save-endpoint-anyway');
    await tester.pumpAndSettle();
    expect(repo.profiles, hasLength(1));
    expect(find.byType(PairingPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the manual form refuses a bad name or password before checking',
    (tester) async {
      final prober = _TrackingProber();
      final graph = createAppDependencies(
        initialLink: Uri(path: '/hosts'),
        profileRepository: MemoryProfiles(),
        endpointProber: prober,
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
      await tester.pumpAndSettle();
      await openForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('endpoint-label')),
        'bad\u0007name',
      );
      await tester.enterText(
        find.byKey(const ValueKey('endpoint-secret')),
        'fake\u0001secret',
      );
      await tapVisible(tester, 'save-endpoint');
      await tester.pumpAndSettle();
      expect(prober.endpoints, isEmpty);
      expect(
        find.text('Enter a valid server name (1–160 characters).'),
        findsOneWidget,
      );
      expect(
        find.text('Check the server password or pairing credentials.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('save anyway checks the name edited after a failed check', (
    tester,
  ) async {
    final repo = MemoryProfiles();
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: repo,
      endpointProber: FakeProber()
        ..assessment = const EndpointAssessment(EndpointStatus.unreachable),
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await openForm(tester);
    await tapVisible(tester, 'save-endpoint');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('endpoint-label')),
      'bad\u0007name',
    );
    await tapVisible(tester, 'save-endpoint-anyway');
    await tester.pumpAndSettle();
    expect(repo.profiles, isEmpty);
    expect(graph.hosts.storageError, isFalse);
    expect(
      find.text('Enter a valid server name (1–160 characters).'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('the add screen is a page, or a dialog from 600 dp, at '
        '${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final graph = createAppDependencies(
        initialLink: Uri(path: '/hosts'),
        profileRepository: MemoryProfiles(),
        endpointProber: FakeProber(),
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-endpoint')));
      await tester.pumpAndSettle();
      final wide = size.width >= 600;
      expect(
        find.ancestor(
          of: find.byType(PairingPage),
          matching: find.byType(Dialog),
        ),
        wide ? findsOneWidget : findsNothing,
      );
      if (wide) {
        // The server list stays beneath; a tap beside the dialog closes it.
        expect(find.byType(HostsPage), findsOneWidget);
        await tester.tapAt(const Offset(16, 400));
        await tester.pumpAndSettle();
        expect(find.byType(PairingPage), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('leaving during a check saves nothing', (tester) async {
    final repo = MemoryProfiles();
    final reply = Completer<EndpointAssessment>();
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: repo,
      endpointProber: FakeProber()..pendingResult = reply.future,
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await openForm(tester);
    await tapVisible(tester, 'save-endpoint');
    await tester.pump();
    // The shell's back button leaves even while the check holds system Back.
    await tester.tap(find.byKey(const ValueKey('workspace-back')));
    await tester.pump();
    reply.complete(const EndpointAssessment(EndpointStatus.compatible));
    await tester.pumpAndSettle();
    expect(find.byType(PairingPage), findsNothing);
    expect(repo.profiles, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a save finishing under a dialog closes only the add screen', (
    tester,
  ) async {
    final repo = MemoryProfiles();
    final reply = Completer<EndpointAssessment>();
    final graph = createAppDependencies(
      initialLink: Uri(path: '/hosts'),
      profileRepository: repo,
      endpointProber: FakeProber()..pendingResult = reply.future,
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
    await tester.pumpAndSettle();
    await openForm(tester);
    await tapVisible(tester, 'save-endpoint');
    await tester.pump();
    final navigator = Navigator.of(
      tester.element(find.byKey(const ValueKey('endpoint-url'))),
      rootNavigator: true,
    );
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const Text('Covering')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    reply.complete(const EndpointAssessment(EndpointStatus.compatible));
    await tester.pumpAndSettle();
    expect(repo.profiles, hasLength(1));
    expect(find.text('Covering'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(PairingPage), findsNothing);
    expect(find.byType(HostsPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
    repo.failLoad = true;
    await tapVisible(tester, 'save-endpoint');
    await tester.pumpAndSettle();
    expect(find.byType(PairingPage), findsNothing);
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
      await tester.tap(
        find.byKey(const ValueKey('endpoint-actions-endpoint_one')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check connection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('endpoint-check-endpoint_one')),
        findsOneWidget,
      );
      expect(graph.hosts.isChecking(profile), isTrue);
      expect(graph.hosts.canCheck(profile), isFalse);
      await tester.tap(
        find.byKey(const ValueKey('endpoint-actions-endpoint_one')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final button = tester.widget<PopupMenuItem<dynamic>>(
        find
            .ancestor(
              of: find.text('Check connection'),
              matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
            )
            .first,
      );
      expect(button.enabled, isFalse);
      Navigator.of(tester.element(find.text('Check connection'))).pop();
      await tester.pump(const Duration(milliseconds: 300));
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
