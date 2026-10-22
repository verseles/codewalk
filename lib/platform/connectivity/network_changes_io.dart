import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nm/nm.dart';

/// The active network as an opaque route, null while offline; the live wake
/// reconnects when it changes.
///
/// Android reports its transports through connectivity_plus. On Linux that
/// plugin only reports a change of the connectivity state, so a handover
/// between two working links (Wi-Fi to a phone's USB tether) is read from
/// NetworkManager's primary connection. A failure ends the feed: the resume
/// wake and the stall watchdog remain.
Stream<Object?> platformNetworkChanges() {
  if (Platform.isLinux) return _networkManagerRoutes();
  if (Platform.isAndroid) return _connectivityRoutes();
  return const Stream.empty();
}

/// The route of a connectivity_plus report: its transports, null when none.
String? connectivityRoute(List<ConnectivityResult> results) {
  final names = {
    for (final result in results)
      if (result != ConnectivityResult.none) result.name,
  }.toList()..sort();
  return names.isEmpty ? null : names.join('+');
}

/// The route of NetworkManager's state: the primary connection and its type,
/// null without connectivity or a primary connection.
String? networkManagerRoute(
  NetworkManagerConnectivityState connectivity,
  String? primary,
  String type,
) {
  if (connectivity == NetworkManagerConnectivityState.none ||
      primary == null ||
      primary.isEmpty) {
    return null;
  }
  return '$primary|$type';
}

/// The current route first, then every change. The feed is subscribed before
/// the snapshot is read, so a change while reading is not lost; a change that
/// arrives first makes the snapshot stale.
Stream<Object?> _connectivityRoutes() {
  final connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? changes;
  var reported = false;
  var done = false;
  late final StreamController<Object?> routes;
  routes = StreamController<Object?>(
    onListen: () {
      changes = connectivity.onConnectivityChanged.listen(
        (results) {
          reported = true;
          if (!done) routes.add(connectivityRoute(results));
        },
        onError: (Object _) {
          done = true;
          unawaited(routes.close());
        },
        cancelOnError: true,
      );
      unawaited(
        connectivity.checkConnectivity().then((results) {
          if (!reported && !done) routes.add(connectivityRoute(results));
        }, onError: (Object _) {}),
      );
    },
    onCancel: () async {
      done = true;
      await changes?.cancel();
    },
  );
  return routes.stream;
}

const _routeProperties = {
  'Connectivity',
  'PrimaryConnection',
  'PrimaryConnectionType',
};

Stream<Object?> _networkManagerRoutes() {
  final client = NetworkManagerClient();
  StreamSubscription<List<String>>? changes;
  var done = false;
  late final StreamController<Object?> routes;
  Future<void> finish() async {
    if (done) return;
    done = true;
    await changes?.cancel();
    await _close(client);
  }

  void emit() {
    try {
      routes.add(
        networkManagerRoute(
          client.connectivity,
          client.primaryConnection?.uuid,
          client.primaryConnectionType,
        ),
      );
    } on Object {
      unawaited(finish().then((_) => routes.close()));
    }
  }

  routes = StreamController<Object?>(
    onListen: () async {
      try {
        await client.connect();
      } on Object {
        await finish();
        await routes.close();
        return;
      }
      if (done) {
        // Cancelled while connecting: the connection opened after the close.
        await _close(client);
        return;
      }
      emit();
      changes = client.propertiesChanged.listen((names) {
        if (!done && names.any(_routeProperties.contains)) emit();
      });
    },
    onCancel: finish,
  );
  return routes.stream;
}

Future<void> _close(NetworkManagerClient client) async {
  try {
    await client.close();
  } on Object {
    // The bus may already be gone; nothing else holds it.
  }
}
