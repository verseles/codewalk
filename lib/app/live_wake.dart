import 'dart:async';

import 'package:flutter/widgets.dart';

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

  /// Triggers inside one window become a single wake.
  final Duration window;
  StreamSubscription<Object?>? _network;
  Timer? _pending;
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

  /// The first route is the current network, not a change. Offline (null)
  /// is only recorded: nothing can reconnect until a network returns.
  void _networkChanged(Object? route) {
    if (_disposed) return;
    final changed = _baseline && route != null && route != _route;
    _baseline = true;
    _route = route;
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
    unawaited(_network?.cancel());
    _network = null;
  }
}
