import 'dart:async';

import 'package:flutter/widgets.dart';

import '../features/hosts/endpoint_health_controller.dart';
import '../features/sessions/session_tabs_controller.dart';
import '../features/sessions/sessions_controller.dart';

/// Tries again what gave up, when trying may work (#467): the app returned,
/// the network changed, or the selected server answers again after it did
/// not. The list and the open conversations never wait for a manual refresh;
/// what needs the user (a credential, a session that is gone) is left alone.
final class LiveRecovery {
  LiveRecovery({
    required this.health,
    required this.catalog,
    required this.tabs,
  }) {
    health.addListener(_healthChanged);
  }

  final EndpointHealthController health;
  final SessionsController catalog;
  final SessionTabsController tabs;
  String? _profile;
  bool _sawOffline = false;
  bool _disposed = false;

  /// Retries the list and the open conversations that gave up, only those
  /// of [host] when one is given.
  void retry({String? host}) {
    if (_disposed) return;
    catalog.recover();
    for (final live in tabs.warmViews) {
      if (live.disposed) continue;
      if (host != null && live.session.host.value != host) continue;
      live.recover();
    }
  }

  /// Only the selected server confirmed Offline and then answering again
  /// retries, and only its own conversations: a server just selected, or one
  /// whose check was merely pending, is not a recovery.
  void _healthChanged() {
    if (_disposed) return;
    final profile = catalog.selectedProfile;
    if (profile?.id != _profile) {
      _profile = profile?.id;
      _sawOffline = false;
    }
    if (profile == null) return;
    switch (health.view(profile).status) {
      case EndpointHealthStatus.offline:
        _sawOffline = true;
      case EndpointHealthStatus.online:
        if (_sawOffline) {
          _sawOffline = false;
          retry(host: profile.id);
        }
      case EndpointHealthStatus.delayed:
        break;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    health.removeListener(_healthChanged);
  }
}

/// Asks the live directory to reconnect now when the app returns from the
/// background or the network changes (`v2-plan.md` §6.10 step 7), instead of
/// waiting for the retry delay or the 45 s stall watchdog, which remain the
/// floor.
///
/// Only a real background arms the resume: `inactive` also covers a
/// notification shade or a desktop focus change, while the stream kept
/// running.
final class LiveWakeCoordinator {
  LiveWakeCoordinator({
    required void Function() wake,
    Stream<Object?>? network,
    this.onNetworkChanged,
    this.window = const Duration(milliseconds: 300),
  }) : _wake = wake {
    // A failed network feed only ends that feed; the resume wake remains.
    _network = network?.listen(
      _networkChanged,
      onError: (Object _) {},
      cancelOnError: true,
    );
  }

  final void Function() _wake;
  final void Function(bool routeChanged)? onNetworkChanged;

  /// Triggers inside one window become a single wake.
  final Duration window;
  StreamSubscription<Object?>? _network;
  Timer? _pending;
  Timer? _networkPending;
  bool _networkRouteChanged = false;
  bool _armed = false;
  bool _baseline = false;
  Object? _route;
  bool _disposed = false;

  void lifecycle(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _armed = true;
      case AppLifecycleState.resumed:
        if (!_armed) return;
        _armed = false;
        _schedule();
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// The first route is the current network, not a change. Every later signal
  /// can prompt a server check; only a different, non-null route wakes streams.
  void _networkChanged(Object? route) {
    if (_disposed) return;
    final observed = _baseline;
    final changed = observed && route != null && route != _route;
    _baseline = true;
    _route = route;
    if (observed) {
      _networkRouteChanged = _networkRouteChanged || changed;
      _networkPending ??= Timer(window, () {
        _networkPending = null;
        final routeChanged = _networkRouteChanged;
        _networkRouteChanged = false;
        if (!_disposed) onNetworkChanged?.call(routeChanged && _route != null);
      });
    }
    if (changed) _schedule();
  }

  void _schedule() {
    _pending ??= Timer(window, () {
      _pending = null;
      if (!_disposed) _wake();
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending?.cancel();
    _pending = null;
    _networkPending?.cancel();
    _networkPending = null;
    unawaited(_network?.cancel());
    _network = null;
  }
}
