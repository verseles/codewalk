import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../../core/errors/exceptions.dart';
import '../../core/i18n/l10n_bridge.dart';
import '../../data/datasources/terminal_remote_datasource.dart';
import '../../data/models/pty_session_model.dart';
import '../../domain/entities/server_profile.dart';
import 'codewalk_terminal_socket.dart';
import 'codewalk_terminal_url.dart';

enum CodewalkTerminalState {
  idle,
  unavailable,
  starting,
  running,
  exited,
  failed,
}

typedef CodewalkTerminalSocketOpener =
    Future<CodewalkTerminalSocketConnection> Function({
      required Uri url,
      Map<String, String>? headers,
    });

class CodewalkTerminalController extends ChangeNotifier {
  CodewalkTerminalController({
    TerminalRemoteDataSource? remoteDataSource,
    CodewalkTerminalSocketOpener? socketOpener,
  }) : _remoteDataSource =
           remoteDataSource ?? _UnavailableTerminalRemoteDataSource(),
       _socketOpener = socketOpener ?? openCodewalkTerminalSocket {
    _terminal = _createTerminal();
  }

  final TerminalRemoteDataSource _remoteDataSource;
  final CodewalkTerminalSocketOpener _socketOpener;

  late Terminal _terminal;
  CodewalkTerminalSocketConnection? _socket;
  StreamSubscription<List<int>>? _outputSubscription;
  Future<void>? _socketDone;
  CodewalkTerminalState _state = CodewalkTerminalState.idle;
  String? _statusMessage;
  String? _targetKey;
  String? _ptyId;
  String? _directory;
  int _cursor = -1;
  Timer? _resizeDebounceTimer;
  int _processToken = 0;
  int _terminalGeneration = 0;
  bool _disposed = false;
  Sink<List<int>>? _utf8DecoderSink;

  Terminal get terminal => _terminal;
  int get terminalGeneration => _terminalGeneration;
  CodewalkTerminalState get state => _state;
  bool get isDeadState =>
      _state == CodewalkTerminalState.failed ||
      _state == CodewalkTerminalState.exited;
  String get statusMessage =>
      _statusMessage ??
      L10nBridge.current?.terminalOpenToConnect ??
      'Open Terminal to connect to the server project terminal.';

  bool get supportsRemoteTerminal => !kIsWeb;

  Future<void> startShell({
    required ServerProfile? serverProfile,
    required String? workingDirectory,
    bool force = false,
  }) async {
    if (!supportsRemoteTerminal) {
      await _resetToUnavailable(
        L10nBridge.current?.terminalNotAvailableYet ??
            'Embedded terminal is not available on this runtime yet.',
      );
      return;
    }

    if (serverProfile == null) {
      await _resetToUnavailable(
        L10nBridge.current?.terminalSelectServer ??
            'Select an active server before opening Terminal.',
      );
      return;
    }

    final normalizedDirectory = workingDirectory?.trim();
    if (normalizedDirectory == null || normalizedDirectory.isEmpty) {
      await _resetToUnavailable(
        L10nBridge.current?.terminalOpenProjectFirst ??
            'Open a project folder before starting the server terminal.',
      );
      return;
    }

    final targetKey = '${serverProfile.id}\u0000$normalizedDirectory';
    final canReuseSession =
        !force && _ptyId != null && _targetKey == targetKey && !isDeadState;

    if (!force && canReuseSession && _socket != null) {
      return;
    }

    if (!canReuseSession || force) {
      await _terminateSession();
    } else {
      await _disconnectSocket();
    }

    final processToken = ++_processToken;
    _terminal = _createTerminal();
    _terminalGeneration += 1;
    _state = CodewalkTerminalState.starting;
    _statusMessage =
        L10nBridge.current?.terminalConnectingTo(serverProfile.displayName) ??
        'Connecting to ${serverProfile.displayName} terminal...';
    _targetKey = targetKey;
    _directory = normalizedDirectory;
    _notify();

    var createdPtyId = _ptyId;
    try {
      if (!canReuseSession || createdPtyId == null) {
        final createdSession = await _remoteDataSource.createPty(
          directory: normalizedDirectory,
        );
        createdPtyId = createdSession.id;
        _ptyId = createdPtyId;
        _cursor = -1;
      }

      final socket = await _socketOpener(
        url: buildCodewalkTerminalSocketUrl(
          baseUrl: serverProfile.url,
          ptyId: createdPtyId,
          directory: normalizedDirectory,
          cursor: _cursor,
        ),
        headers: _authorizationHeaders(serverProfile),
      );
      _socket = socket;

      _utf8DecoderSink?.close();
      _utf8DecoderSink = const Utf8Decoder(allowMalformed: true)
          .startChunkedConversion(
            _TerminalStringSink((decoded) {
              if (_processToken != processToken || decoded.isEmpty) {
                return;
              }
              _terminal.write(decoded);
              if (_state == CodewalkTerminalState.starting) {
                _state = CodewalkTerminalState.running;
                _statusMessage =
                    L10nBridge.current?.terminalConnectedTo(
                      normalizedDirectory,
                      serverProfile.displayName,
                    ) ??
                    'Connected to ${serverProfile.displayName} in $normalizedDirectory';
                _notify();
              }
            }),
          );
      late final StreamSubscription<List<int>> outputSubscription;
      var outputClosed = false;

      Future<void> closeOutput() async {
        if (outputClosed) {
          return;
        }
        outputClosed = true;
        if (identical(_outputSubscription, outputSubscription)) {
          _outputSubscription = null;
        }
        await outputSubscription.cancel();
        _closeUtf8Decoder();
      }

      outputSubscription = socket.messages.listen(
        (bytes) {
          if (_processToken != processToken) {
            return;
          }
          if (_consumeCursorFrame(bytes)) {
            return;
          }
          _utf8DecoderSink?.add(bytes);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_processToken != processToken) {
            return;
          }
          unawaited(closeOutput());
          _socket = null;
          _socketDone = null;
          _state = CodewalkTerminalState.failed;
          _statusMessage =
              L10nBridge.current?.terminalConnectionFailed('$error') ??
              'Terminal connection failed: $error';
          _notify();
        },
      );
      _outputSubscription = outputSubscription;
      _socketDone = socket.done.then((_) async {
        if (_processToken != processToken) {
          return;
        }
        _socket = null;
        _socketDone = null;
        await closeOutput();
        _state = CodewalkTerminalState.exited;
        _statusMessage =
            L10nBridge.current?.terminalDisconnected ??
            'Terminal disconnected.';
        _notify();
      });
    } catch (error) {
      _socket = null;
      if (createdPtyId != null) {
        await _deleteRemotePty(createdPtyId, normalizedDirectory);
        if (_processToken != processToken) {
          return;
        }
        _ptyId = null;
        _targetKey = null;
        _cursor = -1;
      }
      _state = CodewalkTerminalState.failed;
      _statusMessage =
          L10nBridge.current?.terminalConnectionFailed('$error') ??
          'Terminal connection failed: $error';
      _notify();
    }
  }

  Future<void> stop() async {
    await _terminateSession();
    _state = CodewalkTerminalState.idle;
    _statusMessage =
        L10nBridge.current?.terminalSessionClosed ?? 'Terminal session closed.';
    _notify();
  }

  Future<void> _resetToUnavailable(String message) async {
    await _terminateSession();
    _terminal = _createTerminal();
    _terminalGeneration += 1;
    _state = CodewalkTerminalState.unavailable;
    _statusMessage = message;
    _notify();
  }

  Future<void> _terminateSession() async {
    final ptyId = _ptyId;
    final directory = _directory;
    _resizeDebounceTimer?.cancel();
    _resizeDebounceTimer = null;
    _closeUtf8Decoder();
    await _disconnectSocket();
    _targetKey = null;
    _ptyId = null;
    _directory = null;
    _cursor = -1;
    if (ptyId != null && directory != null) {
      await _deleteRemotePty(ptyId, directory);
    }
  }

  Future<void> _disconnectSocket() async {
    final socket = _socket;
    final outputSubscription = _outputSubscription;
    final socketDone = _socketDone;
    _processToken += 1;
    _socket = null;
    _outputSubscription = null;
    _socketDone = null;
    _closeUtf8Decoder();
    await socket?.close();
    await outputSubscription?.cancel();
    if (socket != null) {
      await socketDone;
    }
  }

  void _closeUtf8Decoder() {
    _utf8DecoderSink?.close();
    _utf8DecoderSink = null;
  }

  Future<void> _deleteRemotePty(String ptyId, String directory) async {
    try {
      await _remoteDataSource.deletePty(ptyId: ptyId, directory: directory);
    } catch (_) {
      // A failed cleanup should not block terminal state transitions.
    }
  }

  bool _consumeCursorFrame(List<int> bytes) {
    if (bytes.isEmpty || bytes.first != 0) {
      return false;
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes.sublist(1)));
      if (decoded is Map<String, dynamic>) {
        final cursor = decoded['cursor'];
        if (cursor is int) {
          _cursor = cursor;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, String>? _authorizationHeaders(ServerProfile profile) {
    if (!profile.basicAuthEnabled) {
      return null;
    }
    final username = profile.basicAuthUsername.trim();
    final password = profile.basicAuthPassword.trim();
    if (username.isEmpty || password.isEmpty) {
      return null;
    }
    final encoded = base64Encode(utf8.encode('$username:$password'));
    return <String, String>{'Authorization': 'Basic $encoded'};
  }

  Terminal _createTerminal() {
    final terminal = Terminal(maxLines: 10000);
    terminal.onOutput = (data) {
      _socket?.send(utf8.encode(data));
    };
    terminal.onResize = (width, height, _, _) {
      final ptyId = _ptyId;
      final directory = _directory;
      if (ptyId == null || directory == null) {
        return;
      }
      _resizeDebounceTimer?.cancel();
      _resizeDebounceTimer = Timer(const Duration(milliseconds: 80), () {
        if (_disposed || _ptyId != ptyId || _directory != directory) {
          return;
        }
        unawaited(
          _remoteDataSource
              .resizePty(
                ptyId: ptyId,
                directory: directory,
                rows: height,
                cols: width,
              )
              .catchError((Object error) {
                // Swallow resize exceptions on closed/unreachable PTYs
              }),
        );
      });
    };
    return terminal;
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _resizeDebounceTimer?.cancel();
    unawaited(_terminateSession());
    super.dispose();
  }
}

class _TerminalStringSink implements Sink<String> {
  _TerminalStringSink(this._onData);
  final void Function(String) _onData;

  @override
  void add(String data) => _onData(data);

  @override
  void close() {}
}

class _UnavailableTerminalRemoteDataSource implements TerminalRemoteDataSource {
  @override
  Future<PtySessionModel> createPty({required String directory}) async {
    throw ServerException(
      L10nBridge.current?.terminalTransportUnavailable ??
          'Terminal transport is unavailable.',
    );
  }

  @override
  Future<void> deletePty({
    required String ptyId,
    required String directory,
  }) async {}

  @override
  Future<void> resizePty({
    required String ptyId,
    required String directory,
    required int rows,
    required int cols,
  }) async {}
}
