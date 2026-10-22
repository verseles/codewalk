@TestOn('vm')
library;

import 'dart:async';

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/live_wake.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/connectivity/network_changes_io.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nm/nm.dart';

import 'sessions/live_fakes.dart';

const _window = Duration(milliseconds: 300);

void main() {
  group('LiveWakeCoordinator', () {
    testWidgets('only a return from the background wakes', (tester) async {
      var wakes = 0;
      final wake = LiveWakeCoordinator(wake: () => wakes++);
      addTearDown(wake.dispose);
      wake.lifecycle(AppLifecycleState.resumed);
      await tester.pump(_window);
      expect(wakes, 0, reason: 'nothing left the foreground');
      // A notification shade or a desktop focus change kept the stream.
      wake
        ..lifecycle(AppLifecycleState.inactive)
        ..lifecycle(AppLifecycleState.resumed);
      await tester.pump(_window);
      expect(wakes, 0);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        wake
          ..lifecycle(AppLifecycleState.inactive)
          ..lifecycle(state)
          ..lifecycle(AppLifecycleState.resumed);
        await tester.pump(_window);
      }
      expect(wakes, 3);
      wake.lifecycle(AppLifecycleState.resumed);
      await tester.pump(_window);
      expect(wakes, 3, reason: 'one background, one wake');
    });

    testWidgets('a network change wakes; the same route or offline does not', (
      tester,
    ) async {
      var wakes = 0;
      final network = StreamController<Object?>();
      addTearDown(network.close);
      final wake = LiveWakeCoordinator(
        wake: () => wakes++,
        network: network.stream,
      );
      addTearDown(wake.dispose);
      Future<void> report(Object? route) async {
        network.add(route);
        await tester.pump(_window);
      }

      await report('wifi');
      expect(wakes, 0, reason: 'the first route is the current network');
      await report('wifi');
      expect(wakes, 0);
      await report(null);
      expect(wakes, 0, reason: 'nothing can reconnect while offline');
      await report('wifi');
      expect(wakes, 1, reason: 'the network returned');
      await report('mobile');
      expect(wakes, 2);
    });

    testWidgets('triggers inside one window become a single wake', (
      tester,
    ) async {
      var wakes = 0;
      final network = StreamController<Object?>();
      addTearDown(network.close);
      final wake = LiveWakeCoordinator(
        wake: () => wakes++,
        network: network.stream,
      );
      addTearDown(wake.dispose);
      network.add('wifi');
      await tester.pump();
      wake
        ..lifecycle(AppLifecycleState.paused)
        ..lifecycle(AppLifecycleState.resumed);
      network
        ..add('mobile')
        ..add('wifi')
        ..add('mobile');
      await tester.pump(_window - const Duration(milliseconds: 1));
      expect(wakes, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(wakes, 1);
      await tester.pump(_window * 2);
      expect(wakes, 1);
    });

    testWidgets('a failed network feed keeps the resume wake', (tester) async {
      var wakes = 0;
      final network = StreamController<Object?>();
      addTearDown(network.close);
      final wake = LiveWakeCoordinator(
        wake: () => wakes++,
        network: network.stream,
      );
      addTearDown(wake.dispose);
      network.addError(StateError('no bus'));
      await tester.pump();
      expect(network.hasListener, isFalse);
      wake
        ..lifecycle(AppLifecycleState.paused)
        ..lifecycle(AppLifecycleState.resumed);
      await tester.pump(_window);
      expect(wakes, 1);
    });

    testWidgets('dispose drops a pending wake and the feed', (tester) async {
      var wakes = 0;
      final network = StreamController<Object?>();
      addTearDown(network.close);
      final wake = LiveWakeCoordinator(
        wake: () => wakes++,
        network: network.stream,
      );
      wake
        ..lifecycle(AppLifecycleState.paused)
        ..lifecycle(AppLifecycleState.resumed)
        ..dispose();
      await tester.pump(_window);
      expect(wakes, 0);
      expect(network.hasListener, isFalse);
      wake
        ..lifecycle(AppLifecycleState.paused)
        ..lifecycle(AppLifecycleState.resumed);
      await tester.pump(_window);
      expect(wakes, 0);
    });
  });

  testWidgets('the app wakes its live directory and stops with its graph', (
    tester,
  ) async {
    final directory = LiveDirectory();
    final network = StreamController<Object?>();
    addTearDown(network.close);
    final dependencies = createAppDependencies(
      initialLink: Uri(path: '/'),
      sessionLiveDirectory: () => directory,
      networkChanges: network.stream,
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
    await tester.pumpAndSettle();
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(_window);
    expect(directory.wakes, 1);
    network.add('wifi');
    await tester.pump();
    network.add('ethernet');
    await tester.pump(_window);
    expect(directory.wakes, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(dependencies.isDisposed, isTrue);
    expect(network.hasListener, isFalse);
    expect(directory.closes, 1);
  });

  group('network routes', () {
    test('a connectivity report is its sorted transports', () {
      expect(connectivityRoute([]), isNull);
      expect(connectivityRoute([ConnectivityResult.none]), isNull);
      expect(connectivityRoute([ConnectivityResult.wifi]), 'wifi');
      expect(
        connectivityRoute([ConnectivityResult.wifi, ConnectivityResult.vpn]),
        connectivityRoute([ConnectivityResult.vpn, ConnectivityResult.wifi]),
      );
      expect(
        connectivityRoute([ConnectivityResult.none, ConnectivityResult.mobile]),
        'mobile',
      );
    });

    test('NetworkManager routes follow the primary connection', () {
      const full = NetworkManagerConnectivityState.full;
      expect(
        networkManagerRoute(
          NetworkManagerConnectivityState.none,
          'wifi-uuid',
          '802-11-wireless',
        ),
        isNull,
      );
      expect(networkManagerRoute(full, null, ''), isNull);
      expect(networkManagerRoute(full, '', '802-3-ethernet'), isNull);
      // A handover between two working links keeps full connectivity, so the
      // primary connection is what changes.
      expect(
        networkManagerRoute(full, 'wifi-uuid', '802-11-wireless'),
        isNot(networkManagerRoute(full, 'tether-uuid', '802-3-ethernet')),
      );
      expect(
        networkManagerRoute(
          NetworkManagerConnectivityState.limited,
          'wifi-uuid',
          '802-11-wireless',
        ),
        networkManagerRoute(full, 'wifi-uuid', '802-11-wireless'),
      );
    });
  });
}
