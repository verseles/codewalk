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
      await down();
    }

    _activeProfileId = profileId;
    _publish(const TailscaleState(nodeState: TailscaleNodeState.connecting));

    final stateDir = await _stateDirForProfile(profileId);
    ts.Tailscale.init(
      stateDir: stateDir.path,
      logLevel: kReleaseMode
          ? ts.TailscaleLogLevel.error
          : ts.TailscaleLogLevel.info,
    );
    _listenToNodeState();

    try {
      final status = await _client.up(
        hostname: _hostnameForProfile(profileLabel),
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

  Future<Directory> _stateDirForProfile(String profileId) async {
    final root = await getApplicationSupportDirectory();
    final safeProfileId = profileId.replaceAll(RegExp('[^a-zA-Z0-9_.-]'), '_');
    final dir = Directory('${root.path}/tailscale_profiles/$safeProfileId');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  String _hostnameForProfile(String profileLabel) {
    final normalized = profileLabel
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9-]+'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp('^-|-\$'), '');
    return normalized.isEmpty ? 'codewalk' : 'codewalk-$normalized';
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
