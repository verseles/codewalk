import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tailscale/tailscale.dart' as ts;

import '../i18n/l10n_bridge.dart';
import '../logging/app_logger.dart';
import 'tailscale_peer.dart';
import 'tailscale_state.dart';

class TailscaleService {
  TailscaleService({ts.TailscaleClient? client})
    : _client = client ?? ts.Tailscale.instance;

  final ts.TailscaleClient _client;
  final StreamController<TailscaleState> _stateController =
      StreamController<TailscaleState>.broadcast();
  final StreamController<List<TailscalePeer>> _peerController =
      StreamController<List<TailscalePeer>>.broadcast();

  StreamSubscription<ts.NodeState>? _nodeStateSubscription;
  StreamSubscription<List<ts.TailscaleNode>>? _peerSubscription;
  String? _activeProfileId;
  TailscaleState _state = const TailscaleState.disconnected();
  List<TailscalePeer> _peers = const [];
  ts.NodeState? _lastStreamedNodeState;

  TailscaleState get state => _state;

  /// Current snapshot of discovered tailnet peers (online-first order).
  List<TailscalePeer> get peers => List.unmodifiable(_peers);

  Stream<TailscaleState> get stateChanges => _stateController.stream;

  /// Emits the full peer list whenever the tailnet membership changes.
  Stream<List<TailscalePeer>> get peerChanges => _peerController.stream;

  bool get hasClient => _state.isConnected;

  http.Client get httpClient => _client.http.client;

  Future<TailscaleState> upForProfile({
    required String profileId,
    required String profileLabel,
  }) async {
    if (Platform.isWindows) {
      return _publish(
        TailscaleState(
          nodeState: TailscaleNodeState.unsupported,
          message:
              L10nBridge.current?.tailscaleNotSupportedOnWindows ??
              'Tailscale is not supported on Windows.',
        ),
      );
    }

    if (_activeProfileId != null && _activeProfileId != profileId) {
      // One shared device identity serves every profile: when the node is
      // already connected, retarget without tearing it down. Restarting
      // here used to flap the machine offline on every profile switch.
      if (_state.isConnected) {
        _activeProfileId = profileId;
        return _state;
      }
      await down();
    }

    _activeProfileId = profileId;
    _publish(const TailscaleState(nodeState: TailscaleNodeState.connecting));

    final stateDir = await _sharedStateDir();
    ts.Tailscale.init(
      stateDir: stateDir.path,
      logLevel: kReleaseMode
          ? ts.TailscaleLogLevel.error
          : ts.TailscaleLogLevel.info,
    );
    _listenToNodeState();

    try {
      final status = await _client.up(
        hostname: _deviceHostname(),
        timeout: const Duration(seconds: 30),
      );
      return _publish(_stateFromStatus(status));
    } catch (error, stackTrace) {
      try {
        final status = await _client.status();
        final state = _stateFromStatus(status);
        if (state.isConnected ||
            state.authUrl != null ||
            state.nodeState == TailscaleNodeState.needsLogin ||
            state.nodeState == TailscaleNodeState.needsMachineAuth) {
          return _publish(state);
        }
      } catch (_) {
        // Keep the original start failure as the actionable error below.
      }
      AppLogger.warn(
        '[Tailscale] Failed to start node for profile $profileId',
        error: error,
        stackTrace: stackTrace,
      );
      return _publish(
        TailscaleState(
          nodeState: TailscaleNodeState.error,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> down() async {
    await _nodeStateSubscription?.cancel();
    _nodeStateSubscription = null;
    await _peerSubscription?.cancel();
    _peerSubscription = null;
    try {
      await _client.down();
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Tailscale] Failed to stop node',
        error: error,
        stackTrace: stackTrace,
      );
    }
    _activeProfileId = null;
    _peers = const [];
    _peerController.add(const []);
    _publish(const TailscaleState.disconnected());
  }

  /// Re-reads the native node status without restarting the node.
  ///
  /// Used after the user returns from the browser login flow and by
  /// periodic health polls: the IPN state stream can miss the
  /// needsLogin → running transition while the app is backgrounded.
  Future<TailscaleState> refreshStatus() async {
    if (_activeProfileId == null) return _state;
    try {
      final status = await _client.status();
      return _publish(_stateFromStatus(status));
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Tailscale] Failed to refresh node status',
        error: error,
        stackTrace: stackTrace,
      );
      return _state;
    }
  }

  /// Pulls a one-shot snapshot of current tailnet peers.
  ///
  /// Returns an empty list if the node is not connected.
  Future<List<TailscalePeer>> nodes() async {
    if (!_state.isConnected) return const [];
    try {
      final rawNodes = await _client.nodes();
      final mapped = _mapNodes(rawNodes);
      _peers = mapped;
      _peerController.add(mapped);
      return mapped;
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Tailscale] Failed to fetch peers',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  void _listenToNodeState() {
    _nodeStateSubscription ??= _client.onStateChange.listen((state) {
      _lastStreamedNodeState = state;
      if (state == ts.NodeState.needsLogin ||
          state == ts.NodeState.needsMachineAuth) {
        unawaited(_publishStatusSnapshotIfStill(state));
        return;
      }
      _publish(_stateFromNodeState(state));
      // Once connected, start listening for peer changes and fetch initial list.
      if (state == ts.NodeState.running) {
        _listenToPeerChanges();
        unawaited(nodes());
      }
    });
  }

  /// Subscribes to the upstream peer-change stream (once per [upForProfile]).
  void _listenToPeerChanges() {
    _peerSubscription ??= _client.onNodeChanges.listen((rawNodes) {
      final mapped = _mapNodes(rawNodes);
      _peers = mapped;
      _peerController.add(mapped);
    });
  }

  /// Maps upstream [ts.TailscaleNode] list to domain [TailscalePeer] list,
  /// sorted online-first then by host name.
  static List<TailscalePeer> _mapNodes(List<ts.TailscaleNode> raw) {
    final mapped =
        raw
            .where((n) => n.hostName.isNotEmpty)
            .map(
              (n) => TailscalePeer(
                stableId: n.stableNodeId,
                hostName: n.hostName,
                dnsName: n.dnsName,
                tailscaleIPs: List<String>.unmodifiable(n.tailscaleIPs),
                online: n.online,
                os: n.os,
              ),
            )
            .toList()
          ..sort((a, b) {
            // Online peers first, then alphabetical by hostName.
            if (a.online != b.online) return a.online ? -1 : 1;
            return a.hostName.toLowerCase().compareTo(b.hostName.toLowerCase());
          });
    return List<TailscalePeer>.unmodifiable(mapped);
  }

  Future<void> _publishStatusSnapshotIfStill(ts.NodeState expected) async {
    try {
      final status = await _client.status();
      if (_lastStreamedNodeState != expected) return;
      _publish(_stateFromStatus(status));
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Tailscale] Failed to read node status',
        error: error,
        stackTrace: stackTrace,
      );
      if (_lastStreamedNodeState == expected) {
        _publish(_stateFromNodeState(expected));
      }
    }
  }

  /// Single shared device identity for every server profile.
  ///
  /// Previously each profile owned its own state directory, so every login
  /// registered a brand-new machine (codewalk-cool, codewalk-merc, …) and
  /// profile switches flapped the node offline. One directory means one
  /// machine: log in once, then every Tailscale profile reuses it.
  Future<Directory> _sharedStateDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/tailscale_node');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      await _adoptLegacyProfileIdentity(root, dir);
    }
    return dir;
  }

  /// One-time adoption of a legacy per-profile identity
  /// (`tailscale_profiles/<id>/`) so the user keeps the already-approved
  /// machine instead of registering yet another one. Runs only when there
  /// is exactly one legacy identity holding credentials; otherwise a
  /// fresh interactive login is the honest path.
  Future<void> _adoptLegacyProfileIdentity(
    Directory root,
    Directory target,
  ) async {
    try {
      final legacyRoot = Directory('${root.path}/tailscale_profiles');
      if (!legacyRoot.existsSync()) return;
      final candidates = <Directory>[];
      await for (final entity in legacyRoot.list()) {
        if (entity is! Directory) continue;
        final inner = Directory('${entity.path}/tailscale');
        final source = inner.existsSync() ? inner : entity;
        if (_dirHoldsFiles(source)) candidates.add(source);
      }
      if (candidates.length != 1) return;
      await _copyDir(candidates.single, target);
      AppLogger.info('[Tailscale] Adopted legacy per-profile identity.');
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Tailscale] Legacy identity adoption skipped',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool _dirHoldsFiles(Directory dir) {
    try {
      return dir
          .listSync(recursive: true, followLinks: false)
          .any((entity) => entity is File);
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyDir(Directory source, Directory target) async {
    await for (final entity in source.list(recursive: false)) {
      final name = entity.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      if (entity is Directory) {
        final child = Directory('${target.path}/$name');
        child.createSync(recursive: true);
        await _copyDir(entity, child);
      } else if (entity is File) {
        await entity.copy('${target.path}/$name');
      }
    }
  }

  /// Stable device hostname shared by every profile, so the tailnet sees
  /// a single CodeWalk machine instead of one per server profile.
  String _deviceHostname() {
    final os = Platform.operatingSystem.toLowerCase().replaceAll(
      RegExp('[^a-z0-9-]+'),
      '',
    );
    final safeOs = os.isEmpty ? 'device' : os;
    return 'codewalk-$safeOs';
  }

  TailscaleState _stateFromStatus(ts.TailscaleStatus status) {
    return switch (status.state) {
      ts.NodeState.running => const TailscaleState(
        nodeState: TailscaleNodeState.connected,
      ),
      ts.NodeState.needsLogin => TailscaleState(
        nodeState: TailscaleNodeState.needsLogin,
        authUrl: status.authUrl,
      ),
      ts.NodeState.needsMachineAuth => TailscaleState(
        nodeState: TailscaleNodeState.needsMachineAuth,
        authUrl: status.authUrl,
        message:
            L10nBridge.current?.tailscaleWaitingAdminApproval ??
            'This Tailscale node is waiting for admin approval.',
      ),
      ts.NodeState.starting => const TailscaleState(
        nodeState: TailscaleNodeState.connecting,
      ),
      ts.NodeState.noState ||
      ts.NodeState.stopped => const TailscaleState.disconnected(),
    };
  }

  TailscaleState _stateFromNodeState(ts.NodeState state) {
    return switch (state) {
      ts.NodeState.running => const TailscaleState(
        nodeState: TailscaleNodeState.connected,
      ),
      ts.NodeState.needsLogin => TailscaleState(
        nodeState: TailscaleNodeState.needsLogin,
        authUrl: _state.authUrl,
      ),
      ts.NodeState.needsMachineAuth => TailscaleState(
        nodeState: TailscaleNodeState.needsMachineAuth,
        authUrl: _state.authUrl,
        message:
            L10nBridge.current?.tailscaleWaitingAdminApproval ??
            'This Tailscale node is waiting for admin approval.',
      ),
      ts.NodeState.starting => const TailscaleState(
        nodeState: TailscaleNodeState.connecting,
      ),
      ts.NodeState.noState ||
      ts.NodeState.stopped => const TailscaleState.disconnected(),
    };
  }

  TailscaleState _publish(TailscaleState next) {
    _state = next;
    _stateController.add(next);
    return next;
  }
}
