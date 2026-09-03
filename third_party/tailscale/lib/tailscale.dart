import 'dart:async';

import 'package:http/http.dart' as pkg_http;
import 'package:path/path.dart' as p;
import 'src/api/diag.dart';
import 'src/api/exit_node.dart';
import 'src/api/funnel.dart';
import 'src/api/http.dart';
import 'src/api/identity.dart';
import 'src/api/prefs.dart';
import 'src/api/profiles.dart';
import 'src/api/serve.dart';
import 'src/api/taildrop.dart';
import 'src/api/tcp.dart';
import 'src/api/tls.dart';
import 'src/api/udp.dart';
import 'src/errors.dart';
import 'src/fd_transport.dart' show ensurePosixFdTransportAvailable;
import 'src/ffi_bindings.dart' as native;
import 'src/http_fd_client.dart';
import 'src/status.dart';
import 'src/worker/worker.dart';

export 'src/api/diag.dart'
    hide
        createDiag,
        DiagPingFn,
        DiagMetricsFn,
        DiagDERPMapFn,
        DiagCheckUpdateFn;
export 'src/api/connection.dart'
    hide createFdTailscaleConnection, createFdTailscaleListener;
export 'src/api/exit_node.dart'
    hide
        createExitNode,
        ExitNodeCurrentFn,
        ExitNodeSuggestFn,
        ExitNodeUseByIdFn,
        ExitNodeUseAutoFn,
        ExitNodeClearFn;
export 'src/api/funnel.dart' hide createFunnel;
export 'src/api/http.dart' hide createHttp, createHttpRequestForTesting;
export 'src/api/identity.dart';
export 'src/api/prefs.dart' hide createPrefs, PrefsGetFn, PrefsUpdateFn;
export 'src/api/profiles.dart';
export 'src/api/serve.dart'
    hide
        createServe,
        createPublishedServiceForFunnel,
        ServeForwardFn,
        ServeClearFn;
export 'src/api/taildrop.dart';
export 'src/api/tcp.dart'
    hide createTcp, TcpDialFn, TcpListenFn, TcpCloseListenerFn;
export 'src/api/tls.dart'
    hide createTls, TlsListenFn, TlsCloseListenerFn, TlsDomainsFn;
export 'src/api/udp.dart'
    hide createUdp, createFdTailscaleDatagramBinding, UdpBindFn;
export 'src/errors.dart';
export 'src/status.dart';

const _ownedStateSubdirectory = 'tailscale';
final Uri _defaultControlUrl = Uri.parse('https://controlplane.tailscale.com');

/// Native log verbosity for the embedded Tailscale runtime — controls
/// what the Go side writes to stderr. Dart-side logging (e.g.
/// [TailscaleRuntimeError]) is unaffected.
enum TailscaleLogLevel {
  /// No native logs at all.
  silent,

  /// Only error-level log lines.
  error,

  /// Informational + error logs. Useful during development; noisy in
  /// production.
  info,
}

extension on TailscaleLogLevel {
  int get nativeValue => switch (this) {
    TailscaleLogLevel.silent => 0,
    TailscaleLogLevel.error => 1,
    TailscaleLogLevel.info => 2,
  };
}

/// Testable app-facing contract for an embedded Tailscale node.
///
/// Production code usually gets the real implementation from
/// [Tailscale.instance]. App code can depend on this interface instead, which
/// allows unit tests to provide a fake without loading the native runtime.
abstract interface class TailscaleClient {
  Tcp get tcp;
  Tls get tls;
  Udp get udp;
  Funnel get funnel;
  Http get http;

  Taildrop get taildrop;
  Serve get serve;
  ExitNode get exitNode;
  Profiles get profiles;
  Prefs get prefs;
  Diag get diag;

  Stream<NodeState> get onStateChange;
  Stream<List<TailscaleNode>> get onNodeChanges;
  Stream<TailscaleRuntimeError> get onError;

  Future<TailscaleStatus> up({
    String hostname = '',
    String? authKey,
    bool ephemeral = false,
    Uri? controlUrl,
    Duration timeout = const Duration(seconds: 30),
  });

  Future<TailscaleStatus> status();
  Future<List<TailscaleNode>> nodes();
  Future<TailscaleNode?> nodeByIp(String ip);
  Future<TailscaleNodeIdentity?> whois(String ip);
  Future<void> down();
  Future<void> logout();
}

/// Singleton embedded Tailscale node for the current Dart process.
/// Wraps Tailscale's [tsnet](https://tailscale.com/docs/features/tsnet)
/// userspace library — the Dart app itself becomes a node on the
/// tailnet, no OS-level VPN required.
///
/// This package runs one node per process. Configure it once with
/// [init], then access the singleton through [instance].
///
/// ## Shape
///
/// - **Lifecycle** (top-level): [up], [down], [logout], [status], [nodes],
///   [nodeByIp], [onStateChange], [onNodeChanges], [onError].
/// - **Transport primitives** (namespaced): [tcp], [tls], [udp], [funnel],
///   [http]. Raw TCP uses package-native connection/listener types.
/// - **Feature namespaces**: [taildrop], [serve], [exitNode], [profiles],
///   [prefs].
/// - **Diagnostics**: [diag].
/// - **Identity**: [whois].
class Tailscale implements TailscaleClient {
  Tailscale._();
  static final Tailscale instance = Tailscale._();

  static String? _stateBaseDir;

  pkg_http.Client? _http;
  List<TailscaleNode>? _latestNodes;

  late final _worker = Worker(
    publishState: _stateController.add,
    publishRuntimeError: _errorController.add,
    publishNodes: _publishNodes,
  );

  // Singleton broadcast controllers — live for the process lifetime alongside
  // the embedded Tailscale engine; intentionally never closed.
  // ignore: close_sinks
  final StreamController<NodeState> _stateController =
      StreamController<NodeState>.broadcast();
  // ignore: close_sinks
  final StreamController<TailscaleRuntimeError> _errorController =
      StreamController<TailscaleRuntimeError>.broadcast();
  // ignore: close_sinks
  final StreamController<List<TailscaleNode>> _nodesController =
      StreamController<List<TailscaleNode>>.broadcast();

  static String get _stateDir =>
      p.join(_requireStateBaseDir(), _ownedStateSubdirectory);

  static String _requireStateBaseDir() {
    final stateBaseDir = _stateBaseDir;
    if (stateBaseDir == null) {
      throw const TailscaleUsageException(
        'Call Tailscale.init(stateDir: ...) before using Tailscale.instance.',
      );
    }
    return stateBaseDir;
  }

  static void _requireInitialized() {
    _requireStateBaseDir();
  }

  void _reset() {
    _http?.close();
    _http = null;
    _latestNodes = null;
  }

  void _publishNodes(List<TailscaleNode> nodes) {
    final snapshot = List<TailscaleNode>.unmodifiable(nodes);
    _latestNodes = snapshot;
    _nodesController.add(snapshot);
  }

  Future<List<TailscaleNode>> _snapshotNodes() async {
    final nodes = await _worker.nodes();
    final snapshot = List<TailscaleNode>.unmodifiable(nodes);
    _latestNodes = snapshot;
    return snapshot;
  }

  static bool _sameNodes(List<TailscaleNode>? a, List<TailscaleNode>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ─── Transport namespaces ───────────────────────────────────────────
  @override
  late final Tcp tcp = createTcp(
    dialFn: (host, port, timeout) =>
        _worker.tcpDialConnection(host: host, port: port, timeout: timeout),
    listenFn: (tailnetPort, tailnetHost) =>
        _worker.tcpListenFd(tailnetPort: tailnetPort, tailnetHost: tailnetHost),
    closeListenerFn: (listenerId) =>
        _worker.closeFdListener(listenerId: listenerId),
  );
  @override
  late final Tls tls = createTls(
    listenFn: (tailnetPort, tailnetHost) =>
        _worker.tlsListenFd(tailnetPort: tailnetPort, tailnetHost: tailnetHost),
    closeListenerFn: (listenerId) =>
        _worker.closeFdListener(listenerId: listenerId),
    domainsFn: _worker.tlsDomains,
  );
  @override
  late final Udp udp = createUdp(
    bindFn: (host, port) => _worker.udpBindFd(host: host, port: port),
    defaultAddressFn: () async => (await status()).ipv4,
  );
  @override
  late final Funnel funnel = createFunnel(
    forwardFn: _worker.serveForward,
    clearFn: _worker.serveClear,
  );
  @override
  late final Http http = createHttp(
    clientGetter: () => _http,
    bindFn: (port) => _worker.httpBind(tailnetPort: port),
    closeBindingFn: (bindingId) =>
        _worker.httpCloseBinding(bindingId: bindingId),
  );

  // ─── Feature namespaces ─────────────────────────────────────────────
  @override
  final Taildrop taildrop = Taildrop.instance;
  @override
  late final Serve serve = createServe(
    forwardFn: _worker.serveForward,
    clearFn: _worker.serveClear,
  );
  @override
  late final ExitNode exitNode = createExitNode(
    currentFn: _currentExitNode,
    suggestFn: _suggestExitNode,
    useByIdFn: (stableNodeId) async {
      await _worker.prefsUpdate(PrefsUpdate(exitNodeId: stableNodeId));
    },
    useAutoFn: _worker.exitNodeUseAuto,
    clearFn: () async {
      await _worker.prefsUpdate(const PrefsUpdate(exitNodeId: ''));
    },
    nodeChanges: onNodeChanges,
  );
  @override
  final Profiles profiles = Profiles.instance;
  @override
  late final Prefs prefs = createPrefs(
    getFn: _worker.prefsGet,
    updateFn: _worker.prefsUpdate,
  );

  // ─── Diagnostics ────────────────────────────────────────────────────
  @override
  late final Diag diag = createDiag(
    pingFn: (ip, timeout, type) =>
        _worker.diagPing(ip: ip, timeout: timeout, pingType: type.name),
    metricsFn: _worker.diagMetrics,
    derpMapFn: _worker.diagDERPMap,
    checkUpdateFn: _worker.diagCheckUpdate,
  );

  // ─── Streams ────────────────────────────────────────────────────────

  /// Emits the new [NodeState] whenever the node's lifecycle state changes.
  ///
  /// Consecutive duplicates are filtered except for [NodeState.needsLogin].
  /// A re-auth attempt can produce another `needsLogin` with a fresh auth URL;
  /// callers commonly respond to the state event by calling [status], so those
  /// repeats remain observable.
  @override
  Stream<NodeState> get onStateChange => Stream<NodeState>.multi((controller) {
    NodeState? last;
    final subscription = _stateController.stream.listen(
      (state) {
        if (state == last && state != NodeState.needsLogin) return;
        last = state;
        controller.add(state);
      },
      onError: controller.addError,
      onDone: controller.close,
    );

    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);

  /// Emits the full node list on any change (node joined, left,
  /// went on/off-line, tags or DNS name changed).
  ///
  /// Saves callers from polling [nodes] on a timer. Derived from
  /// the same IPN bus `NotifyInitialNetMap` subscription as
  /// [onStateChange]; subscribers get the current node inventory as
  /// the first emission, then one emission per inventory change.
  @override
  Stream<List<TailscaleNode>> get onNodeChanges =>
      Stream<List<TailscaleNode>>.multi((controller) {
        var canceled = false;
        List<TailscaleNode>? lastEmitted;

        void emitIfChanged(List<TailscaleNode> nodes) {
          if (_sameNodes(lastEmitted, nodes)) return;
          lastEmitted = nodes;
          controller.add(nodes);
        }

        final subscription = _nodesController.stream.listen(
          emitIfChanged,
          onError: controller.addError,
          onDone: controller.close,
        );

        unawaited(() async {
          try {
            final snapshot = _latestNodes ?? await _snapshotNodes();
            if (!canceled) {
              emitIfChanged(snapshot);
            }
          } catch (error, stackTrace) {
            if (!canceled) {
              controller.addError(error, stackTrace);
            }
          }
        }());

        controller.onCancel = () {
          canceled = true;
          return subscription.cancel();
        };
      }, isBroadcast: true);

  /// Background runtime errors pushed from the embedded node.
  @override
  Stream<TailscaleRuntimeError> get onError => _errorController.stream;

  // ─── Lifecycle ──────────────────────────────────────────────────────

  /// Configures the Tailscale library. Call this once at app startup,
  /// alongside other library initializers.
  ///
  /// [stateDir] is an app-owned directory where Tailscale persists
  /// its node identity, keys, and profile data under a `tailscale/`
  /// subdirectory. Pick somewhere durable — on Flutter, the
  /// `application_documents_directory` is a good default. On a fresh
  /// install this directory is empty; after the first successful
  /// [up], it contains credentials that let subsequent launches
  /// reconnect without an auth key.
  static void init({
    required String stateDir,
    TailscaleLogLevel logLevel = TailscaleLogLevel.silent,
  }) {
    if (stateDir.trim().isEmpty) {
      throw const TailscaleUsageException('stateDir must not be empty.');
    }
    final normalizedStateDir = p.normalize(p.absolute(stateDir));

    try {
      ensurePosixFdTransportAvailable();
    } catch (error) {
      throw TailscaleUsageException(
        'POSIX fd transport is not available on this platform.',
        cause: error,
      );
    }

    _stateBaseDir = normalizedStateDir;
    native.duneSetLogLevel(logLevel.nativeValue);
  }

  /// Brings the embedded Tailscale node up and connects to the control
  /// plane — Tailscale's coordination service at
  /// `controlplane.tailscale.com`, or a self-hosted
  /// [Headscale](https://github.com/juanfont/headscale) if you set
  /// [controlUrl]. Registers the node on first launch, reconnects from
  /// persisted credentials on subsequent launches.
  ///
  /// [authKey] is optional. Omit it for interactive enrollment: on first
  /// launch with no persisted state the node enters `needsLogin` and
  /// exposes [TailscaleStatus.authUrl] to complete in a browser.
  /// Provide one from the tailnet admin panel at
  /// <https://login.tailscale.com/admin/settings/keys> (see
  /// <https://tailscale.com/kb/1085/auth-keys>) for unattended enrollment.
  /// Reusable keys let you call [up] from multiple processes. Subsequent
  /// launches can omit it — the persisted session state reconnects
  /// automatically.
  ///
  /// Set [ephemeral] to register this process as a short-lived node. Ephemeral
  /// nodes are removed from the tailnet automatically after they go inactive
  /// by control-plane cleanup. Calling [logout] stops the local node and clears
  /// local credentials, but tailnet removal still follows the control plane's
  /// ephemeral-node cleanup behavior. Use this for CI jobs, preview
  /// environments, disposable tests, and other nodes whose identity should not
  /// outlive the process. This affects registration with the control plane; use
  /// a fresh or cleared `stateDir` passed to [Tailscale.init] when you need to
  /// force a new ephemeral identity.
  ///
  /// [hostname] sets the tailnet-visible hostname and the
  /// [MagicDNS](https://tailscale.com/kb/1081/magicdns) label, so the
  /// node becomes reachable at `<hostname>.<tailnet>.ts.net`. Leave
  /// unset to let the embedded runtime pick the OS default.
  ///
  /// Resolves on the first **stable** state: `running`, `needsLogin`,
  /// or `needsMachineAuth`. This intentionally differs from Go's
  /// `tsnet.Server.Up`, which blocks only on `running` — a Dart app
  /// that needs to drive an in-app auth flow should not have to
  /// re-enter [up] just to see the [TailscaleStatus.authUrl]. Inspect
  /// the returned [TailscaleStatus.state] to decide what to do next:
  ///
  /// - `running` — ready; [http], [tcp], etc. are usable.
  /// - `needsLogin` — open [TailscaleStatus.authUrl] in a browser /
  ///   web view; the node finishes connecting after the user completes
  ///   the flow.
  /// - `needsMachineAuth` — authenticated but awaiting admin approval
  ///   on the control plane (
  ///   [device approval](https://tailscale.com/kb/1099/device-approval)).
  ///
  /// Transitions delivered via [onStateChange]:
  /// - First launch: `noState → starting → running`
  /// - Reconnect with persisted creds: `stopped → starting → running`
  /// - If creds are expired: `stopped → starting → needsLogin` (with
  ///   [TailscaleStatus.authUrl] populated)
  ///
  /// No-op if already running (without a new authKey).
  ///
  /// [timeout] bounds how long [up] waits for the node to reach a stable state
  /// after the native runtime starts. Increase it for slow mobile networks or
  /// self-hosted control planes.
  ///
  /// Throws [TailscaleUpException] if the node fails to reach a
  /// stable state before [timeout] (e.g. control plane unreachable).
  @override
  Future<TailscaleStatus> up({
    String hostname = '',
    String? authKey,
    bool ephemeral = false,
    Uri? controlUrl,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _requireInitialized();
    if (timeout <= Duration.zero) {
      throw const TailscaleUsageException('up timeout must be positive.');
    }
    final resolvedControlUrl = controlUrl ?? _defaultControlUrl;

    // Only count stable states that arrive AFTER start() returns. If up()
    // is called on an already-running node (with a new authKey), the old
    // engine's lingering `running` emission would otherwise satisfy the
    // "first stable state" check before the restart completes.
    final stable = Completer<void>();
    var startReturned = false;
    final sub = onStateChange.listen((state) {
      if (!startReturned) return;
      if (_isStableState(state) && !stable.isCompleted) {
        stable.complete();
      }
    });

    try {
      await _worker.start(
        hostname: hostname,
        authKey: authKey ?? '',
        ephemeral: ephemeral,
        controlUrl: resolvedControlUrl.toString(),
        stateDir: _stateDir,
      );
      _http = TailscaleHttpClient();
      startReturned = true;

      // No-op up() case: the engine is already at a stable state and
      // won't emit another event. Check once post-start so we don't
      // wait on a state change that will never come.
      final postStart = await status();
      if (_isStableState(postStart.state) && !stable.isCompleted) {
        stable.complete();
      }

      try {
        await stable.future.timeout(timeout);
      } on TimeoutException {
        final last = await status();
        throw TailscaleUpException(
          'Node did not reach a stable state within $timeout '
          '(last observed: ${last.state.name}). The control plane may '
          'be unreachable or the tailnet is experiencing issues.',
        );
      }
    } finally {
      await sub.cancel();
    }

    return status();
  }

  static bool _isStableState(NodeState s) =>
      s == NodeState.running ||
      s == NodeState.needsLogin ||
      s == NodeState.needsMachineAuth;

  /// Returns the current node status — lifecycle state, assigned
  /// tailnet IPs, health warnings, and MagicDNS suffix. Node
  /// inventory is separate; call [nodes] when you need it.
  ///
  /// Safe to call before [up] — returns [NodeState.stopped] when
  /// persisted credentials exist (ready to reconnect) and
  /// [NodeState.noState] when they don't.
  @override
  Future<TailscaleStatus> status() async {
    _requireInitialized();
    return _worker.status(stateDir: _stateDir);
  }

  /// Returns the current node inventory — every node on the tailnet
  /// this node is aware of, whether online right now or not.
  ///
  /// Separate from [status] so apps can poll lightweight node state
  /// without re-pulling the full node list on every refresh. For
  /// push-style updates, see [onNodeChanges].
  @override
  Future<List<TailscaleNode>> nodes() {
    _requireInitialized();
    return _snapshotNodes();
  }

  /// Returns the first known node with [ip] in its Tailscale IP list.
  ///
  /// This uses the same inventory snapshot as [nodes]. It returns null when
  /// the IP is unknown or the node has not appeared in the current netmap.
  @override
  Future<TailscaleNode?> nodeByIp(String ip) async {
    _requireInitialized();
    final target = ip.trim();
    if (target.isEmpty) return null;
    for (final node in await nodes()) {
      if (node.tailscaleIPs.contains(target)) return node;
    }
    return null;
  }

  Future<TailscaleNode?> _nodeByStableNodeId(String stableNodeId) async {
    final target = stableNodeId.trim();
    if (target.isEmpty) return null;
    for (final node in await nodes()) {
      if (node.stableNodeId == target) return node;
    }
    return null;
  }

  Future<TailscaleNode?> _currentExitNode() async {
    _requireInitialized();
    // LocalAPI exposes exit-node selection through prefs, while the public
    // API returns a full TailscaleNode. Resolve against a near-current node
    // snapshot; transient null is acceptable while netmap state catches up.
    final prefs = await _worker.prefsGet();
    final nodeSnapshot = await nodes();

    for (final node in nodeSnapshot) {
      if (node.exitNode) return node;
    }

    final requestedId = prefs.exitNodeId;
    if (requestedId != null && requestedId.isNotEmpty) {
      for (final node in nodeSnapshot) {
        if (node.stableNodeId == requestedId) return node;
      }
    }

    return null;
  }

  Future<TailscaleNode?> _suggestExitNode() async {
    _requireInitialized();
    final nodeId = await _worker.exitNodeSuggest();
    if (nodeId == null) return null;
    return _nodeByStableNodeId(nodeId);
  }

  /// Resolves a tailnet IP to the node's identity — stable node ID,
  /// owner login, hostname, and ACL tags — by querying the local
  /// LocalAPI.
  ///
  /// Returns null if [ip] is not known on the current tailnet.
  /// Useful for authorization decisions on incoming connections:
  /// combine with [tcp] `.bind(...)` and check
  /// [TailscaleNodeIdentity.tags] before handling. See
  /// <https://tailscale.com/kb/1068/tags> for the tag model.
  @override
  Future<TailscaleNodeIdentity?> whois(String ip) {
    _requireInitialized();
    return _worker.whois(ip);
  }

  /// Brings the embedded node down while preserving persisted credentials.
  @override
  Future<void> down() async {
    _requireInitialized();
    _reset();
    await _worker.down();
  }

  /// Logs out and clears persisted credentials.
  @override
  Future<void> logout() async {
    _requireInitialized();
    _reset();
    await _worker.logout(_stateDir);
  }
}
