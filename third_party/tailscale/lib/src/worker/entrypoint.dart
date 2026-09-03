part of 'worker.dart';

/// Entrypoint for the background worker isolate that executes
/// commands against the Tailscale native runtime.
void _workerEntrypoint(SendPort sendPort) {
  ReceivePort? commandPort;
  ReceivePort? watcherPort;
  try {
    final initResult = native.duneInitDartAPI(
      ffi.NativeApi.initializeApiDLData,
    );
    if (initResult != 0) {
      sendPort.send(
        const _WorkerBootstrapFailureMessage(
          'Failed to initialize the Dart native API bridge.',
        ),
      );
      return;
    }

    commandPort = ReceivePort();
    watcherPort = ReceivePort();

    native.duneSetDartPort(watcherPort.sendPort.nativePort);

    watcherPort.listen((dynamic message) {
      if (message is! String) return;

      try {
        final parsed = jsonDecode(message) as Map<String, dynamic>;

        if (parsed['type'] == 'error') {
          sendPort.send(
            _WorkerRuntimeErrorEvent(
              TailscaleRuntimeError.fromPushPayload(parsed),
            ),
          );
          return;
        }

        if (parsed['type'] == 'status') {
          final state = NodeState.parse(parsed['state'] as String?);
          sendPort.send(_WorkerStateEvent(state: state));
          return;
        }

        if (parsed['type'] == 'peers') {
          final raw = parsed['peers'] as List<dynamic>? ?? const [];
          sendPort.send(
            _WorkerPeersEvent(peers: TailscaleNode.listFromJson(raw)),
          );
        }
      } catch (_) {
        // Malformed message from Go — ignore.
      }
    });

    commandPort.listen((dynamic message) {
      if (message is! _WorkerCommand) return;

      try {
        switch (message) {
          case _WorkerStartCommand request:
            final _WorkerStartCommand(
              :authKey,
              :controlUrl,
              :ephemeral,
              :hostname,
              :hostNetworkSnapshot,
              :stateDir,
            ) = request;

            // Empty authKey with no persisted state means interactive login:
            // let duneStart run so tsnet can enter NeedsLogin and expose
            // an AuthURL instead of failing here before native startup.

            // Allocate inside the try so any partial-allocation failure
            // (hypothetically OOM mid-sequence) still hits the finally and
            // frees what we managed to allocate. The locals start null and
            // the frees guard on nullness.
            ffi.Pointer<Utf8>? hostnamePtr;
            ffi.Pointer<Utf8>? authKeyPtr;
            ffi.Pointer<Utf8>? controlUrlPtr;
            ffi.Pointer<Utf8>? stateDirPtr;
            ffi.Pointer<Utf8>? hostNetworkSnapshotPtr;

            try {
              hostnamePtr = hostname.toNativeUtf8();
              authKeyPtr = authKey.toNativeUtf8();
              controlUrlPtr = controlUrl.toNativeUtf8();
              stateDirPtr = stateDir.toNativeUtf8();
              hostNetworkSnapshotPtr = hostNetworkSnapshot.toNativeUtf8();

              native.duneStopWatch();
              _callNativeJson(
                () => native.duneSetNetworkInterfaces(hostNetworkSnapshotPtr!),
                onError: TailscaleUpException.new,
              );

              _callNativeJson(
                () => native.duneStart(
                  hostnamePtr!,
                  authKeyPtr!,
                  controlUrlPtr!,
                  stateDirPtr!,
                  ephemeral ? 1 : 0,
                ),
                onError: TailscaleUpException.new,
              );

              native.duneStartWatch();

              sendPort.send(const _WorkerStartResponse());
            } finally {
              if (hostnamePtr != null) calloc.free(hostnamePtr);
              if (authKeyPtr != null) calloc.free(authKeyPtr);
              if (controlUrlPtr != null) calloc.free(controlUrlPtr);
              if (stateDirPtr != null) calloc.free(stateDirPtr);
              if (hostNetworkSnapshotPtr != null) {
                calloc.free(hostNetworkSnapshotPtr);
              }
            }
          case _WorkerHttpBindCommand request:
            final result =
                _callNativeJson(
                      () => native.duneHttpBind(request.tailnetPort),
                      onError: TailscaleHttpException.new,
                    )
                    as Map<String, dynamic>;

            final bindingId = result['bindingId'] as int?;
            final tailnetPort = result['tailnetPort'] as int?;
            if (bindingId == null ||
                bindingId <= 0 ||
                tailnetPort == null ||
                tailnetPort <= 0) {
              throw const TailscaleHttpException(
                'Native runtime did not return a usable HTTP binding.',
              );
            }

            sendPort.send(
              _WorkerHttpBindResponse(
                bindingId: bindingId,
                tailnetAddress: result['tailnetAddress'] as String? ?? '',
                tailnetPort: tailnetPort,
              ),
            );
          case _WorkerHttpCloseBindingCommand request:
            native.duneHttpCloseBinding(request.bindingId);
            sendPort.send(
              const _WorkerAckResponse(_WorkerOperation.httpCloseBinding),
            );
          case _WorkerTcpDialFdCommand request:
            final hostPtr = request.host.toNativeUtf8();
            try {
              final result =
                  _callNativeJson(
                        () => native.duneTcpDialFd(
                          hostPtr,
                          request.port,
                          request.timeoutMillis,
                        ),
                        onError: TailscaleTcpException.new,
                      )
                      as Map<String, dynamic>;

              final fd = result['fd'] as int?;
              if (fd == null || fd < 0) {
                throw const TailscaleTcpException(
                  'Native runtime did not return a usable TCP fd.',
                );
              }

              sendPort.send(
                _WorkerTcpDialFdResponse(
                  fd: fd,
                  localAddress: result['localAddress'] as String? ?? '',
                  localPort: result['localPort'] as int? ?? 0,
                  remoteAddress: result['remoteAddress'] as String? ?? '',
                  remotePort: result['remotePort'] as int? ?? 0,
                ),
              );
            } finally {
              calloc.free(hostPtr);
            }
          case _WorkerTcpListenFdCommand request:
            final hostPtr = request.tailnetHost.toNativeUtf8();
            try {
              final result =
                  _callNativeJson(
                        () => native.duneTcpListenFd(
                          request.tailnetPort,
                          hostPtr,
                        ),
                        onError: TailscaleTcpException.new,
                      )
                      as Map<String, dynamic>;

              final listenerId = result['listenerId'] as int?;
              final localPort = result['localPort'] as int?;
              if (listenerId == null || listenerId <= 0 || localPort == null) {
                throw const TailscaleTcpException(
                  'Native runtime did not return a usable TCP listener.',
                );
              }

              sendPort.send(
                _WorkerTcpListenFdResponse(
                  listenerId: listenerId,
                  localAddress: result['localAddress'] as String? ?? '',
                  localPort: localPort,
                ),
              );
            } finally {
              calloc.free(hostPtr);
            }
          case _WorkerTcpCloseFdListenerCommand request:
            native.duneTcpCloseFdListener(request.listenerId);
            sendPort.send(
              const _WorkerAckResponse(_WorkerOperation.tcpCloseFdListener),
            );
          case _WorkerTlsListenFdCommand request:
            final hostPtr = request.tailnetHost.toNativeUtf8();
            try {
              final result =
                  _callNativeJson(
                        () => native.duneTlsListenFd(
                          request.tailnetPort,
                          hostPtr,
                        ),
                        onError: TailscaleTlsException.new,
                      )
                      as Map<String, dynamic>;

              final listenerId = result['listenerId'] as int?;
              final localPort = result['localPort'] as int?;
              if (listenerId == null || listenerId <= 0 || localPort == null) {
                throw const TailscaleTlsException(
                  'Native runtime did not return a usable TLS listener.',
                );
              }

              sendPort.send(
                _WorkerTlsListenFdResponse(
                  listenerId: listenerId,
                  localAddress: result['localAddress'] as String? ?? '',
                  localPort: localPort,
                ),
              );
            } finally {
              calloc.free(hostPtr);
            }
          case _WorkerUdpBindFdCommand request:
            final hostPtr = request.host.toNativeUtf8();
            try {
              final result =
                  _callNativeJson(
                        () => native.duneUdpBindFd(hostPtr, request.port),
                        onError: TailscaleUdpException.new,
                      )
                      as Map<String, dynamic>;

              final fd = result['fd'] as int?;
              final localPort = result['localPort'] as int?;
              if (fd == null || fd < 0 || localPort == null) {
                throw const TailscaleUdpException(
                  'Native runtime did not return a usable UDP binding.',
                );
              }

              sendPort.send(
                _WorkerUdpBindFdResponse(
                  fd: fd,
                  localAddress: result['localAddress'] as String? ?? '',
                  localPort: localPort,
                ),
              );
            } finally {
              calloc.free(hostPtr);
            }
          case _WorkerWhoIsCommand request:
            final ipPtr = request.ip.toNativeUtf8();
            try {
              final result =
                  _callNativeJson(
                        () => native.duneWhoIs(ipPtr),
                        onError: TailscaleStatusException.new,
                      )
                      as Map<String, dynamic>;
              sendPort.send(
                _WorkerWhoIsResponse(identity: _parseWhoIsResponse(result)),
              );
            } finally {
              calloc.free(ipPtr);
            }
          case _WorkerTlsDomainsCommand():
            final result =
                _callNativeJson(
                      native.duneTlsDomains,
                      onError: TailscaleTlsException.new,
                    )
                    as Map<String, dynamic>;
            final domains =
                (result['domains'] as List?)?.cast<String>() ?? const [];
            sendPort.send(_WorkerTlsDomainsResponse(domains: domains));
          case _WorkerDiagPingCommand request:
            final ipPtr = request.ip.toNativeUtf8();
            final pingTypePtr = request.pingType.toNativeUtf8();
            try {
              final result =
                  _callNativeJson(
                        () => native.duneDiagPing(
                          ipPtr,
                          request.timeoutMillis,
                          pingTypePtr,
                        ),
                        onError: TailscaleDiagException.new,
                      )
                      as Map<String, dynamic>;
              sendPort.send(
                _WorkerDiagPingResponse(result: _parsePingResult(result)),
              );
            } finally {
              calloc.free(ipPtr);
              calloc.free(pingTypePtr);
            }
          case _WorkerDiagMetricsCommand():
            final result =
                _callNativeJson(
                      native.duneDiagMetrics,
                      onError: TailscaleDiagException.new,
                    )
                    as Map<String, dynamic>;
            sendPort.send(
              _WorkerDiagMetricsResponse(
                metrics: result['metrics'] as String? ?? '',
              ),
            );
          case _WorkerDiagDERPMapCommand():
            final result =
                _callNativeJson(
                      native.duneDiagDERPMap,
                      onError: TailscaleDiagException.new,
                    )
                    as Map<String, dynamic>;
            sendPort.send(
              _WorkerDiagDERPMapResponse(map: _parseDERPMap(result)),
            );
          case _WorkerDiagCheckUpdateCommand():
            final result =
                _callNativeJson(
                      native.duneDiagCheckUpdate,
                      onError: TailscaleDiagException.new,
                    )
                    as Map<String, dynamic>;
            sendPort.send(
              _WorkerDiagCheckUpdateResponse(
                clientVersion: _parseClientVersion(result),
              ),
            );
          case _WorkerStatusCommand(:final stateDir):
            sendPort.send(
              _WorkerStatusResponse(
                status: _loadStatusSnapshot(stateDir: stateDir),
              ),
            );
          case _WorkerPeersCommand():
            sendPort.send(_WorkerPeersResponse(peers: _loadPeerSnapshot()));
          case _WorkerPrefsGetCommand():
            final result =
                _callNativeJson(
                      native.dunePrefsGet,
                      onError: TailscalePrefsException.new,
                    )
                    as Map<String, dynamic>;
            sendPort.send(
              _WorkerPrefsResponse(
                operation: _WorkerOperation.prefsGet,
                prefs: _parsePrefs(result),
              ),
            );
          case _WorkerPrefsUpdateCommand request:
            final updatePtr = request.updateJson.toNativeUtf8();
            try {
              final result =
                  _callNativeJson(
                        () => native.dunePrefsUpdate(updatePtr),
                        onError: TailscalePrefsException.new,
                      )
                      as Map<String, dynamic>;
              sendPort.send(
                _WorkerPrefsResponse(
                  operation: _WorkerOperation.prefsUpdate,
                  prefs: _parsePrefs(result),
                ),
              );
            } finally {
              calloc.free(updatePtr);
            }
          case _WorkerExitNodeSuggestCommand():
            final result =
                _callNativeJson(
                      native.duneExitNodeSuggest,
                      onError: TailscaleExitNodeException.new,
                    )
                    as Map<String, dynamic>;
            final nodeId = result['nodeId'] as String?;
            sendPort.send(
              _WorkerExitNodeSuggestResponse(
                nodeId: nodeId == null || nodeId.isEmpty ? null : nodeId,
              ),
            );
          case _WorkerExitNodeUseAutoCommand():
            _callNativeJson(
              native.duneExitNodeUseAuto,
              onError: TailscaleExitNodeException.new,
            );
            sendPort.send(
              const _WorkerAckResponse(_WorkerOperation.exitNodeUseAuto),
            );
          case _WorkerServeForwardCommand request:
            final payloadPtr = request.payloadJson.toNativeUtf8();
            try {
              final result =
                  _callNativeJson(
                        () => native.duneServeForward(payloadPtr),
                        onError:
                            request.operation == _WorkerOperation.funnelForward
                            ? TailscaleFunnelException.new
                            : TailscaleServeException.new,
                      )
                      as Map<String, dynamic>;

              sendPort.send(
                _WorkerServePublicationResponse(
                  operation: request.operation,
                  url: Uri.parse(result['url'] as String? ?? ''),
                  port: result['port'] as int? ?? 0,
                  localAddress: result['localAddress'] as String? ?? '',
                  localPort: result['localPort'] as int? ?? 0,
                  path: result['path'] as String? ?? '/',
                  https: result['https'] as bool? ?? true,
                  funnel: result['funnel'] as bool? ?? false,
                ),
              );
            } finally {
              calloc.free(payloadPtr);
            }
          case _WorkerServeClearCommand request:
            final payloadPtr = request.payloadJson.toNativeUtf8();
            try {
              _callNativeJson(
                () => native.duneServeClear(payloadPtr),
                onError: request.operation == _WorkerOperation.funnelClear
                    ? TailscaleFunnelException.new
                    : TailscaleServeException.new,
              );
              sendPort.send(_WorkerAckResponse(request.operation));
            } finally {
              calloc.free(payloadPtr);
            }
          case _WorkerDownCommand():
            native.duneStopWatch();
            native.duneStop();

            sendPort.send(const _WorkerAckResponse(_WorkerOperation.down));
          case _WorkerLogoutCommand request:
            native.duneStopWatch();

            final stateDirPtr = request.stateDir.toNativeUtf8();
            try {
              _callNativeJson(
                () => native.duneLogout(stateDirPtr),
                onError: TailscaleLogoutException.new,
              );
            } finally {
              calloc.free(stateDirPtr);
            }

            sendPort.send(const _WorkerAckResponse(_WorkerOperation.logout));
        }
      } catch (error) {
        final errorMessage = error is TailscaleException
            ? error.message
            : error.toString();
        final (:code, :statusCode) = switch (error) {
          TailscaleOperationException(:final code, :final statusCode) => (
            code: code,
            statusCode: statusCode,
          ),
          _ => (code: TailscaleErrorCode.unknown, statusCode: null),
        };

        return sendPort.send(
          _WorkerFailureResponse(
            operation: message.operation,
            message: errorMessage,
            code: code,
            statusCode: statusCode,
          ),
        );
      }
    });

    sendPort.send(_WorkerReadyMessage(commandPort.sendPort));
  } catch (error) {
    commandPort?.close();
    watcherPort?.close();
    sendPort.send(
      _WorkerBootstrapFailureMessage(
        'Native worker isolate failed to start: $error',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FFI helpers — called exclusively on the worker isolate.
// ---------------------------------------------------------------------------

String _callNativeString(ffi.Pointer<Utf8> Function() fn) {
  final ptr = fn();
  final result = ptr.toDartString();
  native.duneFree(ptr);
  return result;
}

/// Calls a native function that returns JSON, decodes it, and checks for an
/// `error` key if the result is a map. Throws via [onError] if an error key is
/// present; otherwise returns the decoded value.
/// Factory that wraps a native error-response message with the right
/// operation-specific exception subtype. `code` + `statusCode` plumb
/// through from the Go-side error classification in
/// [tailscale.classifyLocalAPIError] so callers can pattern-match on
/// [TailscaleErrorCode].
typedef _ErrorFactory =
    TailscaleException Function(
      String message, {
      TailscaleErrorCode code,
      int? statusCode,
    });

dynamic _callNativeJson(
  ffi.Pointer<Utf8> Function() fn, {
  required _ErrorFactory onError,
}) {
  final result = jsonDecode(_callNativeString(fn));
  if (result is Map<String, dynamic>) {
    final error = result['error'] as String?;
    if (error != null) {
      throw onError(
        error,
        code: _parseErrorCode(result['code'] as String?),
        statusCode: result['statusCode'] as int?,
      );
    }
  }
  return result;
}

TailscaleErrorCode _parseErrorCode(String? raw) => switch (raw) {
  'notFound' => TailscaleErrorCode.notFound,
  'forbidden' => TailscaleErrorCode.forbidden,
  'conflict' => TailscaleErrorCode.conflict,
  'preconditionFailed' => TailscaleErrorCode.preconditionFailed,
  'featureDisabled' => TailscaleErrorCode.featureDisabled,
  _ => TailscaleErrorCode.unknown,
};

TailscaleStatus _loadStatusSnapshot({String? stateDir}) {
  try {
    final parsed =
        _callNativeJson(
              native.duneStatus,
              onError: TailscaleStatusException.new,
            )
            as Map<String, dynamic>;

    // When the engine isn't running, duneStatus returns {} which parses
    // to noState. If we have a stateDir to check and persisted credentials
    // exist, report stopped instead so consumers can distinguish "was
    // previously authenticated" from "never authenticated".
    if (parsed.isEmpty && stateDir != null) {
      final stateDirPtr = stateDir.toNativeUtf8();
      try {
        if (native.duneHasState(stateDirPtr) != 0) {
          return TailscaleStatus.stopped;
        }
      } finally {
        calloc.free(stateDirPtr);
      }
    }

    return TailscaleStatus.fromJson(parsed);
  } catch (error) {
    if (error is TailscaleStatusException) rethrow;
    throw TailscaleStatusException(
      'Failed to decode native Tailscale status.',
      cause: error,
    );
  }
}

List<TailscaleNode> _loadPeerSnapshot() {
  try {
    final decoded = _callNativeJson(
      native.dunePeers,
      onError: TailscaleStatusException.new,
    );
    if (decoded is! List<dynamic>) {
      throw const TailscaleStatusException(
        'Failed to decode native Tailscale peers.',
      );
    }
    return TailscaleNode.listFromJson(decoded);
  } catch (error) {
    if (error is TailscaleStatusException) rethrow;
    throw TailscaleStatusException(
      'Failed to decode native Tailscale peers.',
      cause: error,
    );
  }
}

TailscalePrefs _parsePrefs(Map<String, dynamic> json) {
  try {
    return TailscalePrefs.fromJson(json);
  } catch (error) {
    throw TailscalePrefsException(
      'Failed to decode native Tailscale prefs.',
      cause: error,
    );
  }
}

TailscaleNodeIdentity? _parseWhoIsResponse(Map<String, dynamic> json) {
  if (json['found'] != true) return null;
  return TailscaleNodeIdentity(
    nodeId: json['nodeId'] as String? ?? '',
    hostName: json['hostName'] as String? ?? '',
    userLoginName: json['userLoginName'] as String? ?? '',
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    tailscaleIPs: (json['tailscaleIPs'] as List?)?.cast<String>() ?? const [],
  );
}

PingResult _parsePingResult(Map<String, dynamic> json) {
  final micros = (json['latencyMicros'] as num?)?.toInt() ?? 0;
  final path = switch (json['path'] as String?) {
    'direct' => PingPath.direct,
    'derp' => PingPath.derp,
    _ => PingPath.unknown,
  };
  return PingResult(
    latency: Duration(microseconds: micros),
    path: path,
    derpRegion: json['derpRegion'] as String?,
  );
}

DERPMap _parseDERPMap(Map<String, dynamic> json) {
  final rawRegions = json['regions'] as Map<String, dynamic>? ?? const {};
  final regions = <int, DERPRegion>{};
  rawRegions.forEach((id, value) {
    final regionId = int.tryParse(id);
    if (regionId == null || value is! Map<String, dynamic>) return;
    regions[regionId] = DERPRegion(
      regionId: (value['regionId'] as num?)?.toInt() ?? regionId,
      regionCode: value['regionCode'] as String? ?? '',
      regionName: value['regionName'] as String? ?? '',
      latitude: (value['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (value['longitude'] as num?)?.toDouble() ?? 0,
      avoid: value['avoid'] as bool? ?? false,
      noMeasureNoHome: value['noMeasureNoHome'] as bool? ?? false,
      nodes: ((value['nodes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_parseDERPNode)
          .toList(growable: false),
    );
  });
  return DERPMap(
    regions: regions,
    omitDefaultRegions: json['omitDefaultRegions'] as bool? ?? false,
  );
}

DERPNode _parseDERPNode(Map<String, dynamic> n) => DERPNode(
  name: n['name'] as String? ?? '',
  hostName: n['hostName'] as String? ?? '',
  ipv4: n['ipv4'] as String?,
  ipv6: n['ipv6'] as String?,
  derpPort: (n['derpPort'] as num?)?.toInt() ?? 0,
  stunPort: (n['stunPort'] as num?)?.toInt() ?? 0,
  canPort80: n['canPort80'] as bool? ?? false,
);

ClientVersion? _parseClientVersion(Map<String, dynamic> json) {
  if (json['available'] != true) return null;
  return ClientVersion(
    latestVersion: json['latestVersion'] as String? ?? '',
    urgentSecurityUpdate: json['urgentSecurityUpdate'] as bool? ?? false,
    notifyText: json['notifyText'] as String?,
  );
}
